package App::JobClock::Command::configure;
use App::JobClock -command;
use Modern::Perl;
use App::JobClock::Constants qw(PERIOD PRECISION HOURS);

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(configure) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'set various parameters' }

sub overview {
    [ abstract() ],
      ['if no value is given for an option its current value is displayed'];
}

sub options {
    return (
        [
            'precision|p:i',
'decimal places of precision in display of time; e.g., --precision=1; default is '
              . PRECISION
        ],
        [
            'start-pay-period|s:s',
            'the first day of some pay period; '
              . 'pay period boundaries will be calculated based on this date and the pay period length; '
              . 'e.g., -s "June 14, 1912"'
        ],
        [
            'length-pay-period|l:i',
'the length of the pay period in days; e.g., --pp-length=7; default is '
              . PERIOD
        ],
        [
            'day-length|d:f',
            'length of workday; e.g., -d 7.5; default is ' . HOURS
        ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('specify some parameter to set or display') unless %$opt;
}

1;
