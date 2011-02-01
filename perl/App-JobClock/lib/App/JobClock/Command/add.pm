package App::JobClock::Command::add;
use App::JobClock -command;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(add) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' <description of event>' }

sub abstract { 'log an event' }

sub overview {
    [ abstract() ],
      [ 'basic example: ' . __PACKAGE__->name . ' munging the widget' ],
      [
'all arguments that are not parameter values are concatenated as a description of the event'
      ],
      ['logging an event simultaneously marks the end of the previous event'],
      ['events may be tagged to mark such things as client, grant, or project'];
}

sub options {
    return (
        [
            'tag|t=s@',
'tag the event; multiple tags are acceptable; e.g., -t foo -t bar -t quux',
        ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('no description provided') unless @$args;
}
1;
