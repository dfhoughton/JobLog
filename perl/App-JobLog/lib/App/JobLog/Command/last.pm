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
