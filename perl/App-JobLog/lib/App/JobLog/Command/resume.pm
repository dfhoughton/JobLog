package App::JobLog::Command::resume;

# ABSTRACT: resume last closed task

use App::JobLog -command;
use Modern::Perl;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(resume) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'resume last closed task' }

sub full_description {
    <<END
Starts a new task with an identical description and tags to the last
task closed.
END
}

1;
