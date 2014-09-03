package App::JobLog::Vacation::Period;

# ABSTRACT: extension of L<App::JobLog::Log::Event> to handle special properties of vacation periods

=head1 DESCRIPTION

C<App::JobLog::Vacation::Period> extends L<App::JobLog::Log::Event> to add repeating events and flexible
time events and to allow a different serialization convention such that events take a single line in their
file.

=cut

use Exporter 'import';
our @EXPORT_OK = qw(
  FLEX
  FIXED
  ANNUAL
  MONTHLY
);

use base 'App::JobLog::Log::Event';
use DateTime;
use App::JobLog::Log::Line;
use App::JobLog::Time qw(tz);
use Carp qw(carp);

use overload '""' => \&to_string;
use overload 'bool' => sub { 1 };

use constant FLEX    => 1;
use constant FIXED   => 2;
use constant ANNUAL  => 1;
use constant MONTHLY => 2;

sub new {
    my ( $class, $log_line, %opts ) = @_;
    $class = ref $class || $class;
    bless {
        log      => $log_line,
        type     => 0,
        repeats  => 0,
        tags     => [],
        events   => [],
        vacation => [],
        %opts
      },
      $class;
}

=method flex

Whether time in a period is "flexible". Flexible time off shrinks or expands to provide
enough work hours to complete the day it occurs in.

=cut

sub flex { $_[0]->{type} == FLEX }

=method fixed

Whether time in a period is "fixed". Fixed periods have a definite start and end time. Regular
vacation time is just a fixed period of virtual work in the day but at nor particular time 
and flexible vacation time is just as much time as you need to fill out your work day, again
without any particular start or end.

=cut

sub fixed { $_[0]->{type} == FIXED }

=method annual

Whether this period repeats annually on a particular range of days in particular months. 

=cut

sub annual { $_[0]->{repeats} == ANNUAL }

=method annual

Whether this period repeats monthly on a particular range of days.

=cut

sub monthly { $_[0]->{repeats} == MONTHLY }

=method repeats

Whether this vacation repeats periodically.

=cut

sub repeats { $_[0]->{repeats} }

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
    $clone->{type}    = $self->{type};
    $clone->{repeats} = $self->{repeats};
    return $clone;
}

=method cmp

Overrides L<App::JobLog::Log::Event>'s C<cmp> method so that repeating vacations sort
above non-repeating ones.

=cut

sub cmp {
    my ( $self, $other ) = @_;

    # when mixed with ordinary events
    if ( ref $other eq 'App::JobLog::Log::Event' ) {

        # treat as an ordinary event if fixed
        return $self->SUPER::cmp($other) if $self->fixed;

        # put after ordinary events
        return 1;
    }
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
     (?<date> (\d{4}\s++\d++\s++\d++\s++\d++\s++\d++\s++\d++) (?{push @dates, $^N}) )
     (?<non_ts> (?&flex) : (?&tags) : (?&description))
     (?<flex> ([012]{2}) (?{$type = $^N}))
     (?<tags> (?:(?&tag)(\s++(?&tag))*+)?)
     (?<tag> ((?:[^\s:\\]|(?&escaped))++) (?{push @tags, $^N}))
     (?<escaped> \\.)
     (?<description> (.++) (?{$description = $^N}))
    )
}xi;

=method parse

Class method parsing line in F<vacation> into a vacation object.

=cut

sub parse {
    my ( $class, $text ) = @_;
    $class = ref $class || $class;
    local ( @dates, $type, @tags, $description );
    if ( $text =~ $re ) {
        my $start = _parse_time( $dates[0] );
        my $end   = _parse_time( $dates[1] );
        my %tags  = map { $_ => 1 } @tags;
        my $tags  = [ map { s/\\(.)/$1/g; $_ } sort keys %tags ];
        $description = [ map { s/\\(.)/$1/g; $_ } ($description) ];
        my ( $type, $repeats ) = split //, $type;
        $obj = $class->new(
            App::JobLog::Log::Line->new(
                description => $description,
                time        => $start,
                tags        => $tags
            ),
            type    => $type,
            repeats => $repeats,
            end     => $end
        );
        return $obj;
    }
    else {
        carp "malformed line in vacation file: '$text'";
    }
    return;
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
    if ( $self->flex ) {
        $text .= FLEX;
    }
    elsif ( $self->fixed ) {
        $text .= FIXED;
    }
    else {
        $text .= 0;
    }
    if ( $self->annual ) {
        $text .= ANNUAL;
    }
    elsif ( $self->monthly ) {
        $text .= MONTHLY;
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
    return 1 if $self->intersects($other);
    my $other_is_period = ref $other eq __PACKAGE__;
    if ( $self->annual || $other_is_period && $other->annual ) {
        if ( $self->start->year != $other->start->year ) {
            if ( !$self->annual ) {
                my $t = $self;
                $self  = $other;
                $other = $t;
            }
            $self = $self->clone;
            my $d = $self->start->year - $other->start->year;
            $self->start->subtract( years => $d );
            $self->end->subtract( years => $d );
            return $self->intersects($other);
        }
    }
    elsif ( $self->monthly || $other_is_period && $other->monthly ) {
        if (   $self->start->year != $other->start->year
            || $self->start->month != $other->start->month )
        {
            if ( !$self->monthly ) {
                my $t = $self;
                $self  = $other;
                $other = $t;
            }
            $self = $self->clone;
            my $d = $self->start->year - $other->start->year;
            $self->start->subtract( years => $d );
            $self->end->subtract( years => $d );
            $d = $self->start->month - $other->start->month;
            $self->start->subtract( months => $d );
            $self->end->subtract( months => $d );
            return $self->intersects($other);
        }
    }
    return 0;
}

=method parts

Converts period into list of displayable parts: time, properties, tags, description.

=cut

sub parts {
    my ($self) = @_;
    return $self->_time, $self->_properties, $self->_tags, $self->_description;
}

=method single_day

Whether this period concerns a single day or a longer span of time.

=cut

sub single_day {
    my ($self) = @_;
    my ( $s, $e ) = ( $self->start, $self->end );
    return $s->year == $e->year && $s->month == $e->month && $s->day == $e->day;
}

# time part of summary
sub _time {
    my ($self) = @_;
    my $fmt;
    if ( $self->annual ) {
        $fmt = '%b %d';
    }
    elsif ( $self->monthly ) {
        $fmt = '%d';
    }
    else {
        $fmt = '%F';
    }
    $fmt .= ' %H:%M:%S' if $self->fixed;
    my $s;
    if ( $self->single_day ) {
        $s = $self->start->strftime($fmt);
    }
    else {
        $s = $self->start->strftime($fmt) . ' -- ' . $self->end->strftime($fmt);
    }
    return $s;
}

# properties part of summary
sub _properties {
    my ($self) = @_;
    my $s;
    if ( $self->fixed ) {
        $s = 'fixed';
    }
    elsif ( $self->flex ) {
        $s = 'flex';
    }
    else {
        $s = '';
    }
    if ( $self->annual ) {
        $s .= ' ' if $s;
        $s .= 'annual';
    }
    elsif ( $self->monthly ) {
        $s .= ' ' if $s;
        $s .= 'monthly';
    }
    return $s;
}

=method overlap

Adjust start and end times for annual or monthly periods then delegates to
superclass method in L<App::JobLog::Log::Event>.

=cut

sub overlap {
    my ( $self, $start, $end ) = @_;
    if ( $self->annual || $self->monthly ) {

        # cloning here should be duplicated work, but better safe than sorry
        my $cloned = 0;
        if (   $self->annual
            || $self->monthly && $self->start->year != $start->year )
        {
            $self   = $self->clone;
            $cloned = 1;
            my $delta = $start->year - $self->start->year;
            $self->start->add( years => $delta );
            $self->end->add( years => $delta );
        }
        if ( $self->monthly && $self->start->month != $start->month ) {
            $self = $self->clone unless $cloned;
            my $delta = $start->month - $self->start->month;
            $self->start->add( months => $delta );
            $self->end->add( months => $delta );
        }
    }
    return $self->SUPER::overlap( $start, $end );
}

# tag part of summary
sub _tags {
    my ($self) = @_;
    return join ', ', @{ $self->tags };
}

# description part of summary
sub _description {
    my ($self) = @_;
    return join '; ', @{ $self->description };
}

1;
