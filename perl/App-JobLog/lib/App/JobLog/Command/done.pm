package App::JobLog::Command::done;

# ABSTRACT: close last open event

use App::JobLog -command;
use Modern::Perl;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(done) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'mark current task as done' }

1;
