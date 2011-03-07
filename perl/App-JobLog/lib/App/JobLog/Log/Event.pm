package App::JobLog::Log::Event;

# ABSTRACT: basically adds an end time to App::JobLog::Log::Line events

use Modern::Perl;
use Class::Autouse qw{DateTime};
use autouse 'App::JobLog::Time' => qw(now);
use autouse 'Carp'              => qw(carp);

# for debugging
use overload '""' => sub {
    $_[0]->data->to_string . '-->'
      . ( $_[0]->is_closed ? $_[0]->end : 'ongoing' );
};
use overload 'bool' => sub { 1 };

=method new

Basic constructor. Expects single L<App::JobLog::Log::Line> argument. Can be called on
instance or class.

=cut

sub new {
    my ( $class, $logline ) = @_;
    $class = ref $class || $class;
    my $self = bless { log => $logline }, $class;
    return $self;
}

=method clone

Create a duplicate of this event.

=cut

sub clone {
    my ($self) = @_;
    my $clone = $self->new( $self->data->clone );
    $clone->end = $self->end->clone unless $self->is_open;
    return $clone;
}

# the portion of an event falling within given interval
sub overlap {
    my ( $self, $start, $end ) = @_;

    # if this falls entirely within interval, return this
    my $c1 = DateTime->compare( $start, $self->start ) || 0;
    my $c2 = DateTime->compare( $end,   $self->end )   || 0;
    if ( $c1 <= 0 && $c2 >= 0 ) {
        return $self;
    }
    return if $self->start >= $end || $start >= $self->end;
    my $s = $c1 < 0 ? $self->start : $start;
    my $e = $c2 < 0 ? $end         : $self->end;
    my $clone = $self->clone;
    $clone->start = $s;
    $clone->end   = $e;
    return $clone;
}

sub data {
    $_[0]->{log};
}

sub start : lvalue {
    $_[0]->data->time;
}

sub end : lvalue {
    $_[0]->{end};
}

sub tags : lvalue {
    $_[0]->data->{tags};
}

sub exists_tag {
    my ( $self, @tags ) = @_;
    $self->data->exists_tag(@tags);
}

sub all_tags {
    my ( $self, @tags ) = @_;
    $self->data->all_tags(@tags);
}

# for sorting
sub cmp {
    my ( $self, $other ) = @_;
    carp 'argument must also be event' unless $other->isa(__PACKAGE__);

    # defer to subclass sort order if other is a subclass and self isn't
    return -$other->cmp($self)
      if ref $self eq __PACKAGE__ && ref $other ne __PACKAGE__;

    my $comparison = DateTime->compare( $self->start, $other->start );
    unless ($comparison) {
        if ( $self->is_closed ) {
            if ( $other->is_closed ) {
                return DateTime->compare( $self->end, $other->end );
            }
            else {
                return 1;
            }
        }
        elsif ( $other->is_closed ) {
            return -1;
        }
        else {
            return 0;
        }
    }
    return $comparison;
}

=method is_closed

Whether an end moment for this event is defined.

=cut

sub is_closed { $_[0]->{end} }

=method is_open

Whether no end moment for this event is defined.

=cut

sub is_open { !$_[0]->is_closed }

=method duration

Duration of event in seconds.

=cut

sub duration {
    my ($self) = @_;
    my $e = $self->is_open ? now : $self->end;
    return $e->epoch - $self->start->epoch;
}

=method split_days

Splits a multi-day event up at the day boundaries.

=cut

sub split_days {
    my ($self) = @_;
    my $days_end =
      $self->start->clone->truncate( to => 'day' )->add( days => 1 );
    if ( $days_end < ( $self->end || now ) ) {
        my @splits;
        my $s = $self->start;
        do {
            my $clone = $self->clone;
            $clone->start = $s;
            $clone->end   = $days_end;
            push @splits, $clone;
            $s = $days_end->clone;
            $days_end->add( days => 1 );
        } while ( $days_end < $self->end );
        my $clone = $self->clone;
        $clone->start = $s;
        $clone->end   = $self->end;
        push @splits, $clone;
        return @splits;
    }
    else {
        return $self;
    }
}

# unrolls a calendrical interval onto a timeline
sub _interval {
    my ( $self, $unit ) = @_;
    my $d2 =
      $self->end->subtract_datetime( $self->start )->in_units( $unit . 's' );
    my $d1 = $self->start->$unit;
    return $d1, $d1 + $d2;
}

=method intersects

Whether the time period of this overlaps with another.

=cut

sub intersects {
    my ( $self, $other ) = @_;
    if ( $self->start > $other->start ) {

        #rearrange so $self is earlier
        my $t = $other;
        $other = $self;
        $self  = $t;
    }
    return $self->is_open || $self->end > $other->start;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
