package App::JobLog::Command::summary;

# ABSTRACT: show what you did during a particular period

use App::JobLog -command;
use Modern::Perl;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(summary) Everything has been initialized.  (Not really.)\n";

    # TODO make this return the number of hours remaining to work
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' <date or date range>' }

sub abstract { 'list tasks with certain properties in a particular time range' }

sub overview {
    [ abstract() ],
      [
"use @{[App::JobLog::Command::info->name]} for further details regarding time expressions"
      ];
}

sub options {
    return (
        [
            'tag|t=s@',
            'filter events to include only those with given tags; '
              . 'multiple tags may be specified; '
              . 'e.g., --tag=foo -t bar'
        ],
        [
            'exclude-tag|T=s@',
            'filter events to exclude those with given tags; '
              . 'multiple tags may be specified; '
              . 'e.g., --exclude-tag=foo -T bar'
        ],
        [
            'time|i=s',
'consider only those portions of events that overlap the given time range; '
              . 'e.g., --time 9:00-12:00 or -i "9:00 AM - 9:00 PM"'
        ],
        [ 'hidden', 'display nothing', { hidden => 1 } ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('no time expression provided') unless @$args;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
