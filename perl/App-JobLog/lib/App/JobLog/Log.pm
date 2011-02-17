package App::JobLog::Log;

# ABSTRACT: the code that lets us interact with the log

use Modern::Perl;
use App::JobLog::Config qw(log init_file);
use App::JobLog::Log::Line;
use IO::All -utf8;
use autouse 'Carp' => qw(carp);
use Class::Autouse qw(DateTime);
use Class::Autouse qw(FileHandle);
use Class::Autouse qw(App::JobLog::Log::Event);

# some stuff useful for searching log
use constant WINDOW   => 30;
use constant LOW_LIM  => 1 / 10;
use constant HIGH_LIM => 1 - LOW_LIM;

# some indices
use constant IO          => 0;
use constant FIRST_EVENT => 1;
use constant LAST_EVENT  => 2;
use constant FIRST_INDEX => 3;
use constant LAST_INDEX  => 4;

# timestamp format
use constant TS => '%Y/%m/%d';

sub new {

    # touch log into existence
    unless ( -e log ) {
        init_file log;
        my $fh = FileHandle->new( log, 'w' );
        $fh->close;
    }

    # using an array to make things a little snappier
    my $self = bless [];
    $self->[IO] = io log;
    return $self;
}

# collects all events in log and returns reference to list
sub all_events {
    my ($self) = @_;

    # reopen log in sequential reading mode
    $self->[IO] = io log;
    my ( @events, $previous );
    while ( my $line = $self->[IO]->getline ) {
        my $ll = App::JobLog::Log::Line->parse($line);
        if ( $ll->is_event ) {
            $previous->end = $ll->time if $previous;
            if ( $ll->is_beginning ) {
                $previous = App::JobLog::Log::Event->new($ll);
                push @events, $previous;
            }
            else {
                $previous = undef;
            }
        }
    }
    return \@events;
}

# makes sure log contains only valid lines, all events are in chronological order,
# and every ending follows a beginning
sub validate {
    my ($self) = @_;
    my ( $i, $previous_event ) = (0);
    while ( my $line = $self->[IO][$i] ) {
        my $ll = App::JobLog::Log::Line->parse($line);
        if ( $ll->is_malformed ) {
            print STDERR "line $i -- '$line' -- is malformed; commenting out\n";
            splice @{ $self->[IO] }, $i, 0,
              App::JobLog::Log::Line->new( comment => 'ERROR; malformed line' );
            $self->[IO][ ++$i ] = $ll->comment_out;
        }
        elsif ( $ll->is_event ) {
            if ($previous_event) {
                if ( DateTime->compare( $previous_event->time, $ll->time ) > 0 )
                {
                    print STDERR
"line $i -- '$line' -- is out of order relative to the last event; commenting out\n";
                    splice @{ $self->[IO] }, $i, 0,
                      App::JobLog::Log::Line->new(
                        comment => 'ERROR; dates out of order' );
                    $self->[IO][ ++$i ] = $ll->comment_out;
                }
                elsif ( $previous_event->is_end && $ll->is_end ) {
                    print STDERR
"line $i -- '$line' -- specifies the end of a task not yet begun; commenting out\n";
                    splice @{ $self->[IO] }, $i, 0,
                      App::JobLog::Log::Line->new( comment =>
                          'ERROR; task end without corresponding beginning' );
                    $self->[IO][ ++$i ] = $ll->comment_out;
                }
                else {
                    $previous_event = $ll;
                }
            }
            elsif ( $ll->is_end ) {
                print STDERR
"line $i -- '$line' -- specifies the end of a task not yet begun; commenting out\n";
                splice @{ $self->[IO] }, $i, 0,
                  App::JobLog::Log::Line->new( comment =>
                      'ERROR; task end without corresponding beginning' );
                $self->[IO][ ++$i ] = $ll->comment_out;
            }
            else {
                $previous_event = $ll;
            }
        }
        $i++;
    }
}

sub first_event {
    my ($self) = @_;
    return $self->[FIRST_EVENT], $self->[FIRST_INDEX] if $self->[FIRST_EVENT];
    my ( $i, $e );
    while ( my $line = $self->[IO][ $i++ ] ) {
        my $ll = App::JobLog::Log::Line->parse($line);
        if ( $ll->is_event ) {
            if ($e) {
                $e->end = $ll->time;
                last;
            }
            else {
                $e = App::JobLog::Log::Event->new($ll);
                $self->[FIRST_INDEX] = $i;
            }
        }
    }
    $self->[FIRST_EVENT] = $e;
    return $e, $self->[FIRST_INDEX];
}

sub last_event {
    my ($self) = @_;
    return $self->[LAST_EVENT], $self->[LAST_INDEX] if $self->[LAST_EVENT];
    my $io = $self->[IO];

    # was hoping to use IO::All::backwards for this, but seems to be broken
    # uncertain how to handle utf8 issue with File::ReadBackwards
    my @lines;
    my $i = $#$io;
    for ( ; $i >= 0 ; $i-- ) {
        my $line = $self->[IO][$i];
        my $ll   = App::JobLog::Log::Line->parse($line);
        if ( $ll->is_event ) {
            push @lines, $ll;
            last if $ll->is_beginning;
        }
    }
    return undef unless @lines;
    my $e = App::JobLog::Log::Event->new( pop @lines );
    $e->end = $lines[0]->time if @lines;
    $self->[LAST_EVENT] = $e;
    $self->[LAST_INDEX] = $i;
    return $e, $i;
}

sub find_events {
    my ( $self, $start, $end ) = @_;
    my $io = $self->[IO];
    my ( $end_event, $bottom, $start_event, $top ) =
      ( $self->last_event, $self->first_event );

    # if the log is empty, return empty list
    return [] unless $start_event && $end_event;

    # if the log concerns events before the time in question, return empty list
    return []
      unless $end_event->is_open
          || DateTime->compare( $start, $end_event->end ) < 0;

    # likewise if it concerns events after
    return [] if DateTime->compare( $start_event->start, $end ) > 0;

    # narrow time range to that in log
    my $c1 = DateTime->compare( $start, $start_event->start ) <= 0;
    my $c2 =
      $end_event->is_open
      ? DateTime->compare( $end, $end_event->start ) >= 0
      : DateTime->compare( $end, $end_event->end ) >= 0;
    return $self->all_events if $c1 && $c2;
    $start = $start_event->start if $c1;
    $end   = $end_event->end     if $c2;

    # matters are simple if what we want is at the start of the log
    if ($c1) {
        my ( $line, $previous, @events );
        while ( my $line = $io->getline ) {
            chomp $line;
            my $ll = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_event ) {
                if ( DateTime->compare( $ll->time, $end ) >= 0 ) {
                    $previous->end = $end if $previous->is_open;
                    last;
                }
                if ( $previous && $previous->is_open ) {
                    $previous->end = $ll->time;
                }
                if ( $ll->is_beginning ) {
                    $previous = App::JobLog::Log::Event->new($ll);
                    push @events, $previous;
                }
            }
        }
        return \@events;
    }

    # matters are likewise simple if what we want is at the end of the log
    if ($c2) {

        # must restart io
        $io = $self->[IO] = io log;
        $io->backwards;
        my ( $line, $previous, @events );
        while ( my $line = $io->getline ) {
            chomp $line;
            my $ll = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_event ) {
                my $e;
                if ( $ll->is_beginning ) {
                    $e = App::JobLog::Log::Event->new($ll);
                    $e->end = $previous->time if $previous;
                    unshift @events, $e;
                }
                if ( DateTime->compare( $ll->time, $start ) <= 0 ) {
                    $e->start = $start if $e;
                    last;
                }
                $previous = $ll;
            }
        }
        return \@events;
    }

    # otherwise, do binary search for first event in range
    my ( $et, $eb ) = ( $start_event->start, $end_event->start );
    my $previous_index;
  OUTER: while (1) {
        return $self->_scan_from( $top, $start, $end )
          if $bottom - $top + 1 <= WINDOW / 2;
        my $index = _estimate_index( $top, $bottom, $et, $eb, $start );
        if ( defined $previous_index && $previous_index == $index ) {

            # search was too clever by half; we've entered an infinite loop
            return $self->_scan_from( $top, $start, $end );
        }
        $previous_index = $index;
        my $event;
        for my $i ( $index .. $#$io ) {
            my $line = $io->[$i];
            my $ll   = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_beginning ) {
                given ( DateTime->compare( $ll->time, $start ) ) {
                    when ( $_ < 0 ) {
                        $top = $i;
                        $et  = $ll->time;
                        next OUTER;
                    }
                    when ( $_ > 0 ) {
                        $bottom = $i;
                        $eb     = $ll->time;
                        next OUTER;
                    }
                    default {

                        # found beginning!!
                        # this should happen essentially never
                        return $self->_scan_from( $i, $start, $end );
                    }
                };
            }
        }
    }
}

# find moment immediately before moment specified
# returns event and index
sub _find_previous {
    my ( $self, $start, $end ) = @_;
    my $io = $self->[IO];
    my ( $end_event, $bottom, $start_event, $top ) =
      ( $self->last_event, $self->first_event );

    # if the log is empty, return empty list
    return () unless $start_event && $end_event;

    # if the log concerns events before the time in question, return empty list
    return ()
      unless $end_event->is_open
          || DateTime->compare( $start, $end_event->end ) < 0;

    # if it concerns events after; return last event and index
    return ( $end_event, $bottom )
      if DateTime->compare( $start_event->start, $end ) > 0;

    # narrow time range to that in log
    my $c1 = DateTime->compare( $start, $start_event->start ) <= 0;
    my $c2 =
      $end_event->is_open
      ? DateTime->compare( $end, $end_event->start ) >= 0
      : DateTime->compare( $end, $end_event->end ) >= 0;
    return $self->all_events if $c1 && $c2;
    $start = $start_event->start if $c1;
    $end   = $end_event->end     if $c2;

    # matters are simple if what we want is at the start of the log
    if ($c1) {

        # not sure whether this is necessary
        $io = $self->[IO] = io log;
        my ( $line, $previous, @events );
        while ( my $line = $io->getline ) {
            chomp $line;
            my $ll = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_event ) {
                if ( DateTime->compare( $ll->time, $end ) >= 0 ) {
                    $previous->end = $end if $previous->is_open;
                    last;
                }
                if ( $previous && $previous->is_open ) {
                    $previous->end = $ll->time;
                }
                if ( $ll->is_beginning ) {
                    $previous = App::JobLog::Log::Event->new($ll);
                    push @events, $previous;
                }
            }
        }
        return \@events;
    }

    # matters are likewise simple if what we want is at the end of the log
    if ($c2) {

        # not sure whether this is necessary
        $io = $self->[IO] = io log;
        $io->backwards;
        my ( $line, $previous, @events );
        while ( my $line = $io->getline ) {
            chomp $line;
            my $ll = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_event ) {
                my $e;
                if ( $ll->is_beginning ) {
                    $e = App::JobLog::Log::Event->new($ll);
                    $e->end = $previous->time if $previous;
                    unshift @events, $e;
                }
                if ( DateTime->compare( $ll->time, $start ) <= 0 ) {
                    $e->start = $start if $e;
                    last;
                }
                $previous = $ll;
            }
        }
        return \@events;
    }

    # otherwise, do binary search for first event in range
    my ( $et, $eb ) = ( $start_event->start, $end_event->start );
    my $previous_index;
  OUTER: while (1) {
        return $self->_scan_from( $top, $start, $end )
          if $bottom - $top + 1 <= WINDOW / 2;
        my $index = _estimate_index( $top, $bottom, $et, $eb, $start );
        if ( defined $previous_index && $previous_index == $index ) {

            # search was too clever by half; we've entered an infinite loop
            return $self->_scan_from( $top, $start, $end );
        }
        $previous_index = $index;
        my $event;
        for my $i ( $index .. $#$io ) {
            my $line = $io->[$i];
            my $ll   = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_beginning ) {
                given ( DateTime->compare( $ll->time, $start ) ) {
                    when ( $_ < 0 ) {
                        $top = $i;
                        $et  = $ll->time;
                        next OUTER;
                    }
                    when ( $_ > 0 ) {
                        $bottom = $i;
                        $eb     = $ll->time;
                        next OUTER;
                    }
                    default {

                        # found beginning!!
                        # this should happen essentially never
                        return $self->_scan_from( $i, $start, $end );
                    }
                };
            }
        }
    }
}

# now that we're close to the section of the log we want, we
# scan it sequentially
sub _scan_from {
    my ( $self, $i, $start, $end ) = @_;
    my $io = $self->[IO];

    # collect events
    my ( $previous, @events );
    for my $index ( $i .. $#$io ) {
        my $line = $io->[$index];
        my $ll   = App::JobLog::Log::Line->parse($line);
        if ( $ll->is_event ) {
            if ($previous) {
                $previous->end = $ll->time if $previous->is_open;
                push @events, $previous
                  if DateTime->compare( $start, $previous->end ) < 0;
            }
            if ( $ll->is_beginning ) {
                last if DateTime->compare( $ll->time, $end ) >= 0;
                $previous = App::JobLog::Log::Event->new($ll);
            }
            else {
                $previous = undef;
            }
        }
    }
    push @events, $previous
      if $previous
          && $previous->is_open
          && DateTime->compare( $previous->start, $end ) < 0;

    # return only overlap
    my @return = map { $_->overlap( $start, $end ) } @events;
    return \@return;
}

sub _estimate_index {
    my ( $top, $bottom, $et, $eb, $s ) = @_;
    my $delta = $bottom - $top + 1;
    my $i;
    if ( $delta > WINDOW ) {
        my $d1       = $s->epoch - $et->epoch;
        my $d2       = $eb->epoch - $et->epoch;
        my $fraction = $d1 / $d2;
        if ( $fraction < LOW_LIM ) {
            $fraction = LOW_LIM;
        }
        elsif ( $fraction > HIGH_LIM ) {
            $fraction = HIGH_LIM;
        }
        $i = sprintf '%.0f', $delta * $fraction;
    }
    else {
        $i = sprintf '%.0f', $delta / 2;
    }
    $i ||= 1;
    return $top + $i;
}

# expects array of event properties
# returns duration of previous event it it was open and
# has been running for more than a day
sub append_event {
    my ( $self, @args ) = @_;
    my $current = @args == 1 ? $args[0] : App::JobLog::Log::Line->new(@args);
    my $io = $self->[IO];
    my $duration;
    if ( $current->is_event ) {
        my ( $previous, $last_index ) = $self->last_event;
        if ($previous) {

            # validation to prevent inconsistency
            die
              'attempting to append event to log younger than last event in log'
              if $current->cmp($previous) < 0;

            # apply default tags
            $current->tags = $previous->tags if $current->tags_unspecified;
            if ( $previous->is_closed
                && _different_day( $previous->end, $current->time )
                || $previous->is_open
                && _different_day( $previous->start, $current->time ) )
            {

                # day changed
                $io->append(
                    App::JobLog::Log::Line->new(
                        comment => $current->time->strftime(TS)
                    )
                )->append("\n");
            }
            if ( $previous->is_open ) {
                $duration =
                  $current->time->subtract_datetime( $previous->start );
                $duration = undef unless $duration->in_units('days');
            }
        }
        else {

            # first record in log
            $io->append(
                App::JobLog::Log::Line->new(
                    comment => $current->time->strftime(TS)
                )
            )->append("\n");
        }

        # cache last event; useful during debugging
        if ( $current->is_beginning ) {
            $self->[LAST_EVENT] = App::JobLog::Log::Event->new($current);
            $self->[LAST_INDEX] = @$io;
        }
        elsif ( $self->[LAST_EVENT] && $self->[LAST_EVENT]->is_open ) {
            $self->[LAST_EVENT]->end = $current->time;
        }
    }
    $io->append($current)->append("\n");
    $io->close;    # flush contents
    return $duration;
}

sub _different_day {
    my ( $d1, $d2 ) = @_;
    return !( $d1->day == $d2->day
        && $d1->month == $d2->month
        && $d1->year == $d2->year );
}

# force all changes to be written to log
sub close {
    my ($self) = @_;
    my $io = $self->[IO];
    $io->close if $io && $io->is_open;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
