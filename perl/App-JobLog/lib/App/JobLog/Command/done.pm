package App::JobLog::Command::done;

# ABSTRACT: close last open event

use App::JobLog -command;
use Modern::Perl;
use Class::Autouse 'App::JobLog::Log';

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $log = App::JobLog::Log->new;
    my ($last) = $log->last_event;
    if ( $last && $last->is_open ) {
        $log->append_event( done => 1 );
    }
    else {
        say 'No currently open event in log.';
    }
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'mark current task as done' }

1;

__END__

=pod

=head1 SYNOPSIS

 houghton@NorthernSpy:~$ job done
 houghton@NorthernSpy:~$ 

=head1 DESCRIPTION

When you invoke L<App::JobLog::Command::add> to append a new event to the log this moment
also marks the end of any previous event. If an event is ongoing and you simply wish to mark its
end -- if you're signing off for the day, for example -- use B<App::JobLog::Command::done>.

=head1 SEE ALSO

L<App::JobLog::Command::add>, L<App::JobLog::Command::resume>

=cut
