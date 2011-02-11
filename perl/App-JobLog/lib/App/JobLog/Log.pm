package App::JobLog::Log;

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
use constant LOW_LIM  => 1 / 5;
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
    my ( $i, $previous_event );
    while ( my $line = $self->[IO][$i] ) {
        my $ll = App::JobLog::Log::Line->parse($line);
        if ( $ll->is_malformed ) {
            carp "line $i -- '$line' -- is malformed; commenting out";
            splice @{ $self->[IO] }, $i, 0,
              App::JobLog::Log::Line->new( comment => 'ERROR; malformed line' );
            $self->[IO][ ++$i ] = $ll->comment_out;
        }
        elsif ( $ll->is_event ) {
            if ($previous_event) {
                if ( DateTime->compare( $previous_event->time, $ll->time ) > 0 )
                {
                    carp
"line $i -- '$line' -- is out of order relative to the last event; commenting out";
                    splice @{ $self->[IO] }, $i, 0,
                      App::JobLog::Log::Line->new(
                        comment => 'ERROR; dates out of order' );
                    $self->[IO][ ++$i ] = $ll->comment_out;
                }
                elsif ( $previous_event->is_end && $ll->is_end ) {
                    carp
"line $i -- '$line' -- specifies the end of a task not yet begun; commenting out";
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
                carp
"line $i -- '$line' -- specifies the end of a task not yet begun; commenting out";
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
  OUTER: while (1) {
        return $self->_scan_from( $top, $start, $end )
          if $bottom - $top + 1 <= WINDOW / 2;
        my $index = _estimate_index( $top, $bottom, $et, $eb, $start );
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
    my $io = shift @$self;
    $io->close if $io && $io->is_open;
}

1;

__END__

=pod

=head1 NAME

App::JobLog::Log - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = App::JobLog::Log->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=head2 new

  my $object = App::JobLog::Log->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<App::JobLog::Log> object.

So no big surprises there...

Returns a new B<App::JobLog::Log> or dies on error.

=head2 dummy

This method does something... apparently.

=head1 SUPPORT

No support is available

=head1 AUTHOR

David Houghton <dfhoughton@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by David Houghton.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
