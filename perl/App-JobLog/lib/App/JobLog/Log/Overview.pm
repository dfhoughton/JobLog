package App::JobClock::Log::Overview;

# ABSTRACT: consolidates App::JobClock::Log::Event objects for display

use Modern::Perl;

require 'Exporter';
our @ISA    = qw(Exporter);
our @EXPORT = qw(
  overview
  MERGE_ALL
  MERGE_ADJACENT
  MERGE_ADJACENT_SAME_TAGS
  MERGE_SAME_DAY
  MERGE_SAME_DAY_SAME_TAGS
  NO_MERGE
);

use constant WRAP => 76;

use constant MERGE_ALL      => 1;
use constant MERGE_ADJACENT => 2;

# default
use constant MERGE_ADJACENT_SAME_TAGS => 3;
use constant MERGE_SAME_TAGS          => 4;
use constant MERGE_SAME_DAY           => 5;
use constant MERGE_SAME_DAY_SAME_TAGS => 6;
use constant NO_MERGE                 => 0;

# given a format and events prints out overview
sub overview {
    my ( $events, $merge_level, $test ) = @_;
    $merge_level ||= MERGE_ADJACENT_SAME_TAGS;
    $test ||= sub { 1 };
    my @items = collect( $events, $merge_level, $test );

    # TODO figure out column widths
    # generate format
    # print columns
}

# takes in a bunch of App::JobClock::Log::Event objects
# returns a bunch of App::JobClock::Log::Overview objects
sub collect {
    my ( $events, $merge_level, $test ) = @_;
    $merge_level ||= MERGE_ADJACENT_SAME_TAGS;
    $test ||= sub { 1 };
    my $one_interval = $merge_level == MERGE_ADJACENT_SAME_TAGS
      || $merge_level == MERGE_ADJACENT;
    my ( @overview, $previous );
  OUTER: for my $e (@$events) {
        if ( $test->($e) ) {
            my $do_merge = 0;
            if ($previous) {
                given ($merge_level) {
                    when (MERGE_ALL) { $do_merge = 1 }
                    when (MERGE_ADJACENT) {
                        $do_merge = $previous->adjacent($e)
                    }
                    when (MERGE_SAME_TAGS) {
                        for my $o (@overview) {
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
                $previous = new( $e, $one_interval );
                push @overview, $previous;
            }
        }
    }
    return @overview;
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

# whether given event is immediately adjacent to last event in overview
sub adjacent {
    my ( $self, $event ) = @_;
    my $d1 = ( $self->events )[-1]->end;
    my $d2 = $event->start;
    return DateTime->compare( $d1, $d2 ) == 0;
}

# add an event to the events overviewed
sub merge { push @{ $_[0]{events} }, $_[1] }

# returns an unformatted list of strings to display
sub columns {
    my ($self) = @_;
    unless ( exists $self->{columns} ) {
        # TODO flesh this out
    }
    return @{ $self->{columns} };
}

# returns unformatted string containing all unique descriptions
# in events overviewed, listing them in the order in which they
# appeared
sub description {
    my ($self) = @_;
    my (%seen, @descriptions);
    my $s = '';
    for my $e ($self->events) {
        for my $d (@{$e->description}) {
            unless ($seen{$d}) {
                $seen{$d} = 1;
                push @descriptions, $d;
            }
        }
    }
    return join('; ', @descriptions);
}

# returns unformatted string containing all unique tags
# in events overviewed, listing them in alphabetical order 
sub tags {
    my ($self) = @_;
    my %seen;
    my $s = '';
    for my $e ($self->events) {
        for my $t (@{$e->tags}) {
            $seen{$t} = 1;
        }
    }
    return sort keys %seen;
}

# accessor for events in overview
sub events { @{ $_[0]->{events} } }

# constructs a single-event overview
# NOTE: not a package method
sub new {
    my ( $event, $one_interval ) = @_;
    die 'requires event argument'
      unless $event && ref $event eq 'App::JobClock::Log::Event';
    return bless { events => [$event], one_interval => $one_interval };
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
