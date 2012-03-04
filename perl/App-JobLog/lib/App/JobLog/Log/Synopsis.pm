package App::JobLog::Log::Synopsis;

# ABSTRACT: consolidates App::JobClock::Log::Event objects for display

=head1 DESCRIPTION

B<App::JobLog::Log::Synopsis> represents a collection of L<App::JobLog::Log::Event> objects merged
together according to some merging rule.

=cut

use Exporter 'import';
our @EXPORT_OK = qw(
  collect
  MERGE_ALL
  MERGE_ADJACENT
  MERGE_ADJACENT_SAME_TAGS
  MERGE_SAME_TAGS
  MERGE_SAME_DAY
  MERGE_SAME_DAY_SAME_TAGS
  MERGE_NONE
);
our %EXPORT_TAGS = (
    merge => [
        qw(
          MERGE_ALL
          MERGE_ADJACENT
          MERGE_ADJACENT_SAME_TAGS
          MERGE_SAME_TAGS
          MERGE_SAME_DAY
          MERGE_SAME_DAY_SAME_TAGS
          MERGE_NONE
          )
    ]
);

use Modern::Perl;
use autouse 'Carp'              => qw(carp);
use autouse 'App::JobLog::Time' => qw(now);
use Class::Autouse qw(DateTime);

use constant MERGE_ALL                => 1;
use constant MERGE_ADJACENT           => 2;
use constant MERGE_ADJACENT_SAME_TAGS => 3;
use constant MERGE_SAME_TAGS          => 4;
use constant MERGE_SAME_DAY           => 5;
use constant MERGE_SAME_DAY_SAME_TAGS => 6;
use constant MERGE_NONE               => 0;

=method collect

Only exported function of B<App::JobLog::Log::Synopsis>, C<collect> exects a reference
to a L<App::JobLog::Log::Day> and a merge level. It then generates all the synopses
appropriate to the given level in the given day, storing these in the day under the
key C<synopses>.

=cut

# takes in a bunch of App::JobClock::Log::Event objects
# returns a bunch of App::JobClock::Log::Synopsis objects
sub collect {
    my ( $day, $merge_level ) = @_;
    my ( @synopses, $previous, @current_day );
    for my $e ( @{ $day->events }, @{ $day->vacation } ) {
        my $do_merge = 0;
        my $mergand  = $previous;
        if ($previous) {
            for ($merge_level) {
                when (MERGE_ALL)      { $do_merge = 1 }
                when (MERGE_ADJACENT) { $do_merge = $previous->adjacent($e) }
                when (MERGE_SAME_TAGS) {
                    for my $o (@synopses) {
                        if ( $o->same_tags($e) ) {
                            $mergand  = $o;
                            $do_merge = 1;
                            last;
                        }
                    }
                }
                when (MERGE_SAME_DAY) { $do_merge = 1 }
                when (MERGE_SAME_DAY_SAME_TAGS) {
                    for my $s (@current_day) {
                        if ( $s->same_tags($e) ) {
                            $do_merge = 1;
                            $mergand  = $s;
                            last;
                        }
                    }
                }
                when (MERGE_ADJACENT_SAME_TAGS) {
                    $do_merge = $previous->adjacent($e)
                      && $previous->same_tags($e)
                }
                when (MERGE_NONE) { $do_merge = 0 }
                default { carp 'unfamiliar merge level' };
            }
        }

        # keep vacation and regular events apart
        $do_merge &&= ref $mergand->last_event eq ref $e;

        if ($do_merge) {
            $mergand->merge($e);
        }
        else {
            $previous = _new( $e, $merge_level );
            push @synopses,    $previous;
            push @current_day, $previous;
        }
    }
    $day->{synopses} = \@synopses;
}

# test to make sure this and the given event
sub same_tags {
    my ( $self, $event ) = @_;
    for my $e ( $self->events ) {
        return 0
          unless $e->all_tags( @{ $event->tags } )
              && $event->all_tags( @{ $e->tags } );
    }
    return 1;
}

sub same_day {
    my ( $self, $event ) = @_;
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
    return 1 if !$event->can('end');    # notes are always considered adjacent
    my $d1 = ( $self->events )[-1]->end || now;
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
        for my $e ( $self->events ) {
            for my $d ( @{ $e->data->description } ) {
                unless ( $seen{$d} ) {
                    $seen{$d} = 1;
                    chomp $d;    # got newline from log
                    push @descriptions, $d;
                }
            }
        }
        my $s = $descriptions[0];
        for my $d ( @descriptions[ 1 .. $#descriptions ] ) {
            $s .= $s =~ /\w$/ ? '; ' : ' ';
            $s .= $d;
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
    return ( sort keys %seen );
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

Accessor for events in Synopsis. Returns these as list rather than reference.

=cut

sub events { @{ $_[0]->{events} } }

=method last_event

Accessor for last event in synopsis.

=cut

sub last_event { ( $_[0]->events )[-1] }

# constructs a single-event synopsis
# NOTE: not a package method
sub _new {
    my ( $event, $merge_level ) = @_;
    carp 'requires event argument'
      unless $event && $event->isa('App::JobLog::Log::Note');
    my ( $one_interval, $one_day );
    for ($merge_level) {
        when (MERGE_ALL)      { ( $one_interval, $one_day ) = ( 0, 0 ) }
        when (MERGE_ADJACENT) { ( $one_interval, $one_day ) = ( 1, 1 ) }
        when (MERGE_ADJACENT_SAME_TAGS) {
            ( $one_interval, $one_day ) = ( 1, 1 )
        }
        when (MERGE_SAME_TAGS) { ( $one_interval, $one_day ) = ( 0, 0 ) }
        when (MERGE_SAME_DAY)  { ( $one_interval, $one_day ) = ( 0, 1 ) }
        when (MERGE_SAME_DAY_SAME_TAGS) {
            ( $one_interval, $one_day ) = ( 0, 1 )
        }
        when (MERGE_NONE) { ( $one_interval, $one_day ) = ( 1, 1 ) }
    }
    return bless {
        events       => [$event],
        one_interval => $one_interval,
        one_day      => $one_day
      },
      __PACKAGE__;
}

=method single_interval

Whether all events contained in this synopsis are adjacent.

=cut

sub single_interval { $_[0]->{one_interval} }

=method single_day

Whether all events contained in this synopsis occur in the same day.

=cut

sub single_day { $_[0]->{one_day} }

=method duration

Duration in seconds of all events contained in this Synopsis.

=cut

sub duration {
    my ($self) = @_;
    my @events = $self->events;
    return 0 unless $events[0]->can('end');    # notes have no duration
    if ( $self->single_interval ) {
        my ( $se, $ee ) = ( $events[0], $events[$#events] );
        my ( $start, $end ) = ( $se->start, $ee->end || now );
        return $end->epoch - $start->epoch;
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
    my ( $se, $ee ) = ( $events[0], $events[$#events] );
    if ( @events == 1 && !$se->can('end') ) {    # single note
        return $se->start->strftime('%l:%M %P');
    }
    my ( $start, $end ) =
      ( $se->start, $ee->can('end') ? $ee->end : $ee->start );
    my $s;
    if ($end) {
        return 'vacation'
          if ref $se eq 'App::JobLog::Vacation::Period' && !$se->fixed;
        my $same_period = $start->hour < 12 && $end->hour < 12
          || $start->hour >= 12 && $end->hour >= 12;
        if (   $same_period
            && $start->hour == $end->hour
            && $start->minute == $end->minute )
        {
            $s = $start->strftime('%l:%M %P');
        }
        else {
            my ( $f1, $f2 ) =
              ( $same_period ? '%l:%M' : '%l:%M %P', '%l:%M %P' );
            $s = $start->strftime($f1) . ' - ' . $end->strftime($f2);
        }
    }
    else {
        $s = $start->strftime('%l:%M %P') . ' - ongoing';
    }
    $s =~ s/  / /;    # strftime tends to add in an extra space
    $s =~ s/^ //;
    return $s;
}

1;
