package App::JobLog::Log::Event;

# ABSTRACT: basically adds an end time to App::JobLog::Log::Line events

=head1 DESCRIPTION

B<App::JobLog::Log::Event> represents an interval in time from the log, providing accessors
to all the information about this event. It is similar to L<App::JobLog::Log::Line>, delegating
to an instance of the latter for much functionality, but it contains additional methods to
handle the properties of intervals of time as distinct from points.

=cut

use parent qw(App::JobLog::Log::Note);

use Modern::Perl;
use Class::Autouse qw{DateTime};
use autouse 'App::JobLog::Time' => qw(now);
use autouse 'Carp'              => qw(carp);

# for debugging
use overload '""' => sub {
   $_[0]->data->to_string . '-->'
     . ( $_[0]->is_closed ? $_[0]->end : 'ongoing' );
};

=method clone

Create a duplicate of this event.

=cut

sub clone {
   my ($self) = @_;
   my $clone = $self->new( $self->data->clone );
   $clone->end = $self->end->clone unless $self->is_open;
   return $clone;
}

=method overlap

Expects two L<DateTime> objects as arguments. Returns the portion of this event
overlapping the interval so defined.

=cut

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

=method end

End of event. Is lvalue method.

=cut

sub end : lvalue {
   $_[0]->{end};
}

=method cmp

Used to sort events. E.g.,

 my @sorted_events = sort { $a->cmp($b) } @unsorted;

=cut

sub cmp {
   my ( $self, $other ) = @_;
   my $comparison = $self->SUPER::cmp($other);
   unless ($comparison) {
      if ( $other->isa(__PACKAGE__) ) {
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
   my $e = $self->end || now;
   if ( $days_end < $e ) {
      my @splits;
      my $s = $self->start;
      do {
         my $clone = $self->clone;
         $clone->start = $s;
         $s            = $days_end->clone;
         $clone->end   = $s;
         push @splits, $clone;
         $days_end->add( days => 1 );
      } while ( $days_end < $e );
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
