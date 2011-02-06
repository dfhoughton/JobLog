package App::JobLog::Command::resume;
use App::JobLog -command;
use Modern::Perl;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(resume) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'resume last closed task' }

1;
