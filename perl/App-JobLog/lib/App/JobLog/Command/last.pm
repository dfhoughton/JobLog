package App::JobLog::Command::last;

# ABSTRACT: show details of last recorded event

use App::JobLog -command;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(last) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'describe the last task recorded' }

1;
