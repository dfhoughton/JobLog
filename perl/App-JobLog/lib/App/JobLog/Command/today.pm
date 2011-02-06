package App::JobClock::Command::today;
use App::JobClock -command;
use App::JobClock::Command::summary;
use Class::Autouse qw{DateTime};
use Modern::Perl;

sub execute {
    my ( $self, $opt, $args ) = @_;

    # display everything done today
    'App::JobClock::Command::summary'->execute( $opt, 'today' );
    if ( exists $opt->{finished} ) {

        # adjust options
        my $start = $opt->{finished} || 'today';
        delete $opt->{finished};
        $opt->{hidden} = 1;
        _when_finished( $start, $opt );
    }
}

#
# Display stop time
#
sub _when_finished {
    my ( $start, $opt ) = @_;

    my $remaining =
      'App::JobClock::Command::summary'->execute( $opt, "$start - today" );
    if ( $remaining == 0 ) {
        print "you are just now done\n";
    }
    else {
        my $now  = DateTime->now;
        my $then = DateTime->clone;
        $then->add( hours => $remaining );
        my $duration = $then->subtract_datetime($now);
        if ( $duration->days > 0 ) {
            print 'you were done';
            my ( $weeks, $days, $hours, $minutes, $seconds ) =
              $duration->in_units( 'weeks', 'days', 'hours', 'minutes',
                'seconds' );
            no strict 'refs';
            for my $period qw(weeks days hours minutes seconds) {
                print ' ' . _grammatical_number( $period, $$period );
            }
            printf " %s\n", $remaining < 0 ? 'ago' : 'from now';
        }
        else {
            printf "you %s done at %s\n",
              $remaining < 0 ? 'were' : 'will be',
              $then->strftime('%l:%M %p');
        }
    }
}

sub _grammatical_number {
    my ( $term, $units ) = @_;
    my $base = " $units $term";
    $base = $base . 's' if $units > 1;
    return $base;
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'what has happened today' }

sub overview {
    [ abstract() ], ['basically a specialized variant of summary command'];
}

sub options {
    return (
        [
            'finished|f:s',
            'show when you can stop working given hours already work; '
              . 'optional argument indicates span to calculate hours over or start time; '
              . 'e.g., --finished yesterday or --finished payperiod'
        ],
    );
}

1;
