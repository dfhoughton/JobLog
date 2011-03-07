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

__END__

=pod

=head1 SYNOPSIS

 houghton@NorthernSpy:~$ job last
 Sunday,  6 March, 2011
   7:36 - 7:37 pm  0.01  bar, foo  something to add; and still more                                                                                                  
 
   TOTAL HOURS 0.01
   bar         0.01
   foo         0.01
 houghton@NorthernSpy:~$ job resume
 houghton@NorthernSpy:~$ job today
 Monday,  7 March, 2011
   8:01 am - ongoing  0.00  bar, foo  something to add; and still more                                                                                                  
 
   TOTAL HOURS 0.00
   bar         0.00
   foo         0.00

=head1 DESCRIPTION

B<App::JobLog::Command::resume> lets you begin a new event identical in tags and description to
the last one. If the most recent task is ongoing an error message is emitted.

=head1 SEE ALSO

L<App::JobLog::Command::last>, L<App::JobLog::Command::add>

=cut
