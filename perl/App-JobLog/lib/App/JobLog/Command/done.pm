package App::JobLog::Command::done;

# ABSTRACT: close last open event

use App::JobLog -command;
use Modern::Perl;
use Class::Autouse 'App::JobLog::Log';

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $log = App::JobLog::Log->new;
    my ($last) = $log->last_event;
    if ( $last->is_open ) {
        $log->append_event( done => 1 );
    }
    else {
        say 'No currently open event in log.';
    }
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'mark current task as done' }

1;
