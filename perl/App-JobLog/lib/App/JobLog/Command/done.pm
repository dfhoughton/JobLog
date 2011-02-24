package App::JobLog::Command::done;

# ABSTRACT: close last open event

use App::JobLog -command;
use Modern::Perl;
use Class::Autouse 'App::JobLog::Log';

sub execute {
    my ( $self, $opt, $args ) = @_;

    App::JobLog::Log->new->append_event( done => 1 );
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'mark current task as done' }

1;
