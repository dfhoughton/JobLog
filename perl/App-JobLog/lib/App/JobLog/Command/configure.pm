package App::JobClock::Command::configure;
use App::JobClock -command;
use Modern::Perl;
use App::JobClock::Constants qw(PERIOD PRECISION HOURS);
use Class::Autouse qw{App::JobClock::Config};

sub execute {
    my ( $self, $opt, $args ) = @_;
    _list_params() if $opt->{list};
    if ( exists $opt->{precision} ) {
        my $precision = App::JobClock::Config->precision( $opt->{precision} );
        say "precision set to $precision";
    }
    if ( exists $opt->{'start-pay-period'} ) {
    }
    if ( exists $opt->{'length-pay-period'} ) {
        my $length_pp = App::JobClock::Config->pay_period_length(
            $opt->{'length-pay-period'} );
        say "length of pay period in days set to $length_pp";
    }
    if ( exists $opt->{'day-length'} ) {
        my $day_length =
          App::JobClock::Config->day_length( $opt->{'day-length'} );
        say "length of work day set to $day_length";
    }
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'set or display various parameters' }

sub options {
    return (
        [
            'precision|p=i',
            'decimal places of precision in display of time; '
              . 'e.g., --precision = 1; '
              . 'default is '
              . PRECISION
        ],
        [
            'start-pay-period|s=s',
            'the first day of some pay period; '
              . 'pay period boundaries will be calculated based on this date and the pay period length; '
              . 'e.g., -s "June 14, 1912"'
        ],
        [
            'length-pay-period|l=i',
            'the length of the pay period in days; e.g., --pp-length= 7;
              default is '
              . PERIOD
        ],
        [
            'day-length|d=f',
            'length of workday; ' . 'e.g., -d 7.5; ' . 'default is ' . HOURS
        ],
        [ 'list|l', 'list all configuration parameters' ],
    );
}

#
# list values of all params
#
sub _list_params {
    my @params = qw(precision day_length pay_period_length start_pay_period);
    my ( $l1, $l2, %h ) = ( 0, 0 );
    for my $method (@params) {
        my $l     = length $method;
        my $value = App::JobClock::Config->$method;
        $value = 'not defined' unless defined $value;
        $l1         = $l if $l > $l1;
        $l          = length $value;
        $l2         = $l if $l > $l2;
        $h{$method} = $value;
    }
    my $format = '%-' . $l1 . 's %' . $l2 . "s\n";
    for my $method (@params) {
        my $value = $h{$method};
        $method =~ s/_/ /g;
        printf $format, $method, $value;
    }
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('specify some parameter to set or display') unless %$opt;
}

1;
