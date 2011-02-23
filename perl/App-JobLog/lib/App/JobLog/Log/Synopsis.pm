package App::JobClock::Log::Synopsis;

# ABSTRACT: consolidates App::JobClock::Log::Event objects for display

use Modern::Perl;

require 'Exporter';
our @ISA    = qw(Exporter);
our @EXPORT = qw(
  synopsis
  MERGE_ALL
  MERGE_ADJACENT
  MERGE_ADJACENT_SAME_TAGS
  MERGE_SAME_DAY
  MERGE_SAME_DAY_SAME_TAGS
  NO_MERGE
);

use constant MERGE_ALL      => 1;
use constant MERGE_ADJACENT => 2;

# default
use constant MERGE_ADJACENT_SAME_TAGS => 3;
use constant MERGE_SAME_TAGS          => 4;
use constant MERGE_SAME_DAY           => 5;
use constant MERGE_SAME_DAY_SAME_TAGS => 6;
use constant NO_MERGE                 => 0;

# given a format and events prints out synopsis
sub synopsis {
    my ( $events, $merge_level, $test ) = @_;
    $merge_level ||= MERGE_ADJACENT_SAME_TAGS;
    $test ||= sub { 1 };
    my @items = collect( $events, $merge_level, $test );
    return @items;
}

# takes in a bunch of App::JobClock::Log::Event objects
# returns a bunch of App::JobClock::Log::Synopsis objects
sub collect {
    my ( $events, $merge_level, $test ) = @_;
    $merge_level ||= MERGE_ADJACENT_SAME_TAGS;
    $test ||= sub { 1 };
    my $one_interval = $merge_level == MERGE_ADJACENT_SAME_TAGS
      || $merge_level == MERGE_ADJACENT;
    my ( @Synopsis, $previous );
  OUTER: for my $e ( map { $_->split_days } @$events ) {
        if ( $test->($e) ) {
            my $do_merge = 0;
            if ($previous) {
                given ($merge_level) {
                    when (MERGE_ALL) { $do_merge = 1 }
                    when (MERGE_ADJACENT) {
                        $do_merge = $previous->adjacent($e)
                    }
                    when (MERGE_SAME_TAGS) {
                        for my $o (@Synopsis) {
                            if ( $o->same_tags($e) ) {
                                $o->merge($e);
                                next OUTER;
                            }
                        }
                    }
                    when (MERGE_SAME_DAY) {
                        $do_merge = $previous->same_day($e)
                    }
                    when (MERGE_SAME_DAY_SAME_TAGS) {
                        $do_merge = $previous->same_day($e)
                          && $previous->same_tags($e)
                    }
                    when (MERGE_ADJACENT_SAME_TAGS) {
                        $do_merge = $previous->adjacent($e)
                          && $previous->same_tags($e)
                    }
                    when (NO_MERGE) {

                        # NO OP
                    }
                    default { die 'unfamiliar merge level' }
                }
            }
            if ($do_merge) {
                $previous->merge($e);
            }
            else {
                $previous = _new( $e, $one_interval );
                push @Synopsis, $previous;
            }
        }
    }
    return @Synopsis;
}

# test to make sure this and the given event
sub same_tags {
    my ( $self, $event );
    for my $e ( $self->events ) {
        return 0
          unless $e->all_tags( $event->tags ) && $event->all_tags( $e->tags );
    }
    return 1;
}

sub same_day {
    my ( $self, $event );
    my $d1 = ( $self->events )[-1]->end;
    my $d2 = $event->start;
    return
         $d1->day == $d2->day
      && $d1->month == $d2->month
      && $d1->year == $d2->year;
}

# whether given event is immediately adjacent to last event in synopsis
sub adjacent {
    my ( $self, $event ) = @_;
    my $d1 = ( $self->events )[-1]->end;
    my $d2 = $event->start;
    return DateTime->compare( $d1, $d2 ) == 0;
}

# add an event to the events described
sub merge { push @{ $_[0]{events} }, $_[1] }

=method date

L<DateTime> object representing first moment in first event in synopsis.

=cut

sub date { $_[0]->{events}[0]->start }

=method description

Returns unformatted string containing all unique descriptions
in events described, listing them in the order in which they
appeared and separating distinct events with semicolons when they
end in a word character.

=cut

sub description {
    my ($self) = @_;
    unless ( exists $self->{description} ) {
        my ( %seen, @descriptions );
        my $s = '';
        for my $e ( $self->events ) {
            for my $d ( @{ $e->description } ) {
                unless ( $seen{$d} ) {
                    $seen{$d} = 1;
                    push @descriptions, $d;
                }
            }
        }
        my $s = $descriptions[0];
        for my $d ( @descriptions[ 1 .. $#descriptions ] ) {
            $s .= $s =~ /\w$/ ? '; ' : ' ';
        }
        $self->{description} = $s;
    }
    return $self->{description};
}

=method tags

Returns unformatted string containing all unique tags
in events described, listing them in alphabetical order.

=cut

sub tags {
    my ($self) = @_;
    my %seen;
    my $s = '';
    for my $e ( $self->events ) {
        for my $t ( @{ $e->tags } ) {
            $seen{$t} = 1;
        }
    }
    return sort keys %seen;
}

=method tag_string

Returns stringification of tags in the events described, sorting them alphabetically
and separating distinct tags with commas.

=cut

sub tag_string {
    my ($self) = @_;
    $self->{tag_string} = join ', ', $self->tags
      unless exists $self->{tag_string};
    return $self->{tag_string};
}

=method events

Accessor for events in Synopsis.

=cut

sub events { @{ $_[0]->{events} } }

# constructs a single-event synopsis
# NOTE: not a package method
sub _new {
    my ( $event, $one_interval ) = @_;
    die 'requires event argument'
      unless $event && ref $event eq 'App::JobClock::Log::Event';
    return bless { events => [$event], one_interval => $one_interval };
}

=method single_interval

Whether all events contained in this synopsis are adjacent.

=cut

sub single_interval { $_[0]->{one_interval} }

=method duration

Duration in seconds of all events contained in this Synopsis.

=cut

sub duration {
    my (@self) = @_;
    my @events = $self->events;
    if ( $self->one_interval ) {
        return $events[$#events]->end -epoch - $events[0]->start->epoch;
    }
    else {
        my $d = 0;
        $d += $_->duration for @events;
        return $d;
    }
}

=method time_fmt

Formats time interval of events.

=cut

sub time_fmt {
    my ($self) = @_;
    my @events = $self->events;
    my ( $start, $end ) = ( $events[0]->start, $events[$#events]->end );
    my $same_period = $start->hour < 12 && $end->hour < 12
      || $start->hour >= 12 && $end->hour >= 12;
    my ( $f1, $f2 ) = ( $same_period ? '%l:%M' : '%l:%M %P', '%l:%M %P' );
    my $s =
      $start->strftime($f1) . ' - ' . $self->is_open
      ? 'ongoing'
      : $end->strftime($f2);
    return $s;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
