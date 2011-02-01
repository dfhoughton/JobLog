package App::JobClock::Command::today;
use App::JobClock -command;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(today) Everything has been initialized.  (Not really.)\n";
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
