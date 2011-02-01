package App::JobClock::Command::edit;
use App::JobClock -command;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(edit) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'open a text editor to edit the log' }

sub overview {
    return (
        [ abstract() ],
        [
'checks log syntax after saving, commenting out ill-formed lines and printing a warning'
        ],
        [
'requires the preferred editor to have been specified; see configure command'
        ],
    );
}

1;
