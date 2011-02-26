package App::JobLog::Vacation::Period;

# ABSTRACT: extension of L<App::JobLog::Log::Event> to handle special properties of vacation periods

=head1 DESCRIPTION

C<App::JobLog::Vacation::Period> extends L<App::JobLog::Log::Event> to add repeating events and flexible
time events and to allow a different serialization convention such that events take a single line in their
file.

=cut

use base 'App::JobLog::Log::Event';
use DateTime;
use App::JobLog::Log::Line;
use App::JobLog::Time qw(tz);
use Carp qw(carp);

use overload '""' => \&to_string;

=method flex

Whether time in a period so marked is "flexible". Flexible time off shrinks or expands to provide
enough work hours to complete the day it occurs in.

Lvalue method.

=cut

sub flex : lvalue {
    $_[0]->{flex};
}

=method annual

Whether this period repeats annually on a particular range of days in particular months. Lvalue method.

=cut

sub annual : lvalue {
    $_[0]->{annual};
}

=method annual

Whether this period repeats monthly on a particular range of days. Lvalue method.

=cut

sub monthly : lvalue {
    $_[0]->{monthly};
}

=method description

The description of the vacation period. Lvalue method.

=cut

sub description : lvalue {
    $_[0]->data->description;
}

=method clone

Overrides L<App::JobLog::Log::Event>'s C<clone> method to add cloning of special vacation
properties.

=cut

sub clone {
    my ($self) = @_;
    my $clone = $self->SUPER::clone;
    $clone->flex    = $self->flex;
    $clone->annual  = $self->annual;
    $clone->monthly = $self->monthly;
    return $clone;
}

=method cmp

Overrides L<App::JobLog::Log::Event>'s C<cmp> method so that repeating vacations sort
above non-repeating ones.

=cut

sub cmp {
    my ( $self, $other );

    # when mixed with ordinary events they should sort as ordinary events
    return $self->SUPER::cmp($other) if ref $other eq 'App::JobLog::Log::Event';
    if ( $self->monthly ) {
        return -1 unless $other->monthly;
    }
    elsif ( $self->annual ) {
        return 1 if $other->monthly;
        return -1 unless $other->annual;
    }
    return $self->SUPER::cmp($other);
}

# some global variables for use in BNF regex
our ( @dates, $type, @tags, $description );

# log line parser
my $re = qr{
    ^ (?&ts) : (?&non_ts) $
    (?(DEFINE)
     (?<ts> (?&date) : (?&date) )
     (?<date> (\d{4}+\s++\d++\s++\d++\s++\d++\s++\d++\s++\d++) (?{push @dates, $^N}) )
     (?<non_ts> (?&flex) : (?&tags) : (?&description))
     (?<flex> ([01][012]) (?{$type = $^N}))
     (?<tags> (?:(?&tag)(\s++(?&tag))*+)?)
     (?<tag> ((?:[^\s:\\]|(?&escaped))++) (?{push @tags, $^N}))
     (?<escaped> \\.)
     (?<description> (.++) (?{$description = $^N}))
    )
}xi;

# for parsing a line in an existing log
sub parse {
    my ( undef, $text ) = @_;
    local ( @dates, $type, @tags, $description );
    if ( $text =~ $re ) {
        my $start = _parse_time( $dates[0] );
        $obj->{time} = $start;
        my %tags = map { $_ => 1 } @tags;
        $obj->{tags} = [ map { s/\\(.)/$1/g; $_ } sort keys %tags ];
        $obj->{description} = [ map { s/\\(.)/$1/g; $_ } ($description) ];
        $obj = __PACKAGE__->new($obj);
        my ( $is_flex, $repeats ) = split //, $type;
        $obj->flex    = $is_flex;
        $obj->annual  = $repeats == 1;
        $obj->monthly = $repeats == 2;
        $obj->end     = _parse_time( $dates[1] );
        return $obj;
    }
    else {
        carp "malformed line in vacation file: '$text'";
    }
    return undef;
}

sub _parse_time {
    my @time = split /\s++/, $_[0];
    $date = DateTime->new(
        year      => $time[0],
        month     => $time[1],
        day       => $time[2],
        hour      => $time[3],
        minute    => $time[4],
        second    => $time[5],
        time_zone => tz,
    );
    return $date;
}

=method to_string

Serializes period into something printable in the vacation file.

=cut

sub to_string {
    my ($self) = @_;
    my $text = $self->data->time_stamp( $self->start );
    $text .= ':';
    $text .= $self->data->time_stamp( $self->end );
    $text .= ':';
    $text .= $self->flex;
    if ( $self->annual ) {
        $text .= 1;
    }
    elsif ( $self->montly ) {
        $text .= 2;
    }
    else {
        $text .= 0;
    }
    $text .= ':';
    $self->tags ||= [];
    my %tags = map { $_ => 1 } @{ $self->tags };
    $text .= join ' ', map { s/([:\\\s])/\\$1/g; $_ } sort keys %tags;
    $text .= ':';
    $self->description ||= [];
    $text .= join ';',
      map { ( my $d = $_ ) =~ s/([;\\])/\\$1/g; $d } @{ $self->description };
}

=method conflicts

Determines whether two events overlap in time.

=cut

sub conflicts {
    my ( $self, $other ) = @_;
    my $test =
      _overlap_test( $self->_interval('day'), $other->_interval('day') );
    return $day_test
      if $self->monthly || ref $other eq __PACKAGE__ && $other->monthly;
    if ($test) {
        $test =
          _overlap_test( $self->_interval('month'),
            $other->_interval('month') );
        return $test
          if $self->annual || ref $other eq __PACKAGE__ && $other->annual;
        if ($test) {
            return _overlap_test( $self->_interval('year'),
                $other->_interval('year') );
        }
    }
    return 0;
}

=method overlap

Determines the portion of a vacation period that overlaps an event.

=cut

sub overlap {
    my ($self, $event) = @_;
    return undef unless $self->conflicts($event);
    my $clone = $self->clone;
    return undef;
    # TODO figure out complexities of this
}

# unrolls a calendrical interval onto a timeline
sub _interval {
    my ( $self, $unit ) = @_;
    my $d2 =
      $self->end->subtract_datetime( $self->start )->in_units( $unit . 's' );
    my $d1 = $self->start->$unit;
    return $d1, $d1 + $d2;
}

# determine whether two calendrical intervals overlap
sub _overlap_test {
    my ( $s1, $e1, $s2, $e2 ) = @_;
    return 1 if $s1 == $s2;
    my ( $i1, $i2, $it ) = ( [ $s1, $e1 ], [ $s2, $e2 ] );
    if ( $s1 > $s2 ) {
        $it = $i1;
        $i1 = $i2;
        $i2 = $it;
    }
    return $i1->[1] >= $i2[0];
}

=method parts

Converts period into list of displayable parts: time, properties, tags, description.

=cut

sub parts {
    # TODO 
}

1;
