package App::JobLog::Command::resume;

# ABSTRACT: resume last closed task

use App::JobLog -command;
use Modern::Perl;
use Class::Autouse 'App::JobLog::Log';
use autouse 'App::JobLog::Time' => qw(now);

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $log = App::JobLog::Log->new;
    my ($e) = $log->last_event;
    $self->usage_error('empty log') unless $e;
    $self->usage_error('last event ongoing') unless $e->is_closed;

    my $ll = $e->data->clone;
    $ll->time = now;
    $log->append_event($ll);
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
