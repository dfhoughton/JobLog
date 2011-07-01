package App::JobLog::Command::last;

# ABSTRACT: show details of last recorded event

use Modern::Perl;
use App::JobLog -command;
use Class::Autouse qw(
  App::JobLog::Log
  App::JobLog::Command::summary
);

sub execute {
    my ( $self, $opt, $args ) = @_;

    my ($e) = App::JobLog::Log->new->last_event;
    if ($e) {
        my $start = $e->start->strftime('%F at %H:%M:%S %p');
        my $end = $e->is_open ? 'now' : $e->end->strftime('%F at %H:%M:%S %p');
        $opt->{merge} = 'no_merge';
        'App::JobLog::Command::summary'->execute( $opt, ["$start - $end"] );
    }
    else {
        say 'empty log';
    }
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'describe the last task recorded' }

1;

__END__

=pod

=head1 SYNOPSIS

 houghton@NorthernSpy:~$ job last
 Sunday,  6 March, 2011
   7:36 - 7:37 pm  0.01  widget  something to add                                                                                                                  
 
   TOTAL HOURS 0.01
   widget      0.01

=head1 DESCRIPTION

B<App::JobLog::Command::last> simply tells you the last event in the log. This is useful if you
want to know whether you ever punched out, for example, or if you want to know what tags a new
event will inherit, what task you would be resuming, and so forth.

=head1 SEE ALSO

L<App::JobLog::Command::summary>, L<App::JobLog::Command::today>, L<App::JobLog::Command::resume>, L<App::JobLog::Command::tags>,
L<App::JobLog::Command::modify>

=cut
