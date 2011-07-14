package App::JobLog::Command::today;

# ABSTRACT: show what has happened today

use App::JobLog -command;
use Modern::Perl;
use App::JobLog::Command::summary;
use autouse 'App::JobLog::Time' => qw(now);

use constant FORMAT => '%l:%M:%S %p on %A, %B %d, %Y';

sub execute {
    my ( $self, $opt, $args ) = @_;

    # display everything done today
    App::JobLog::Command::summary->execute( $opt, ['today'] );
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'what has happened today' }

sub full_description {
    <<END;
List what has happened today.

This is basically a specialized variant of the @{[App::JobLog::Command::summary->name]} command.
END
}

1;

__END__

=pod

=head1 SYNOPSIS

 houghton@NorthernSpy:~$ job today --help
 job <command>
 
 job today [-f] [long options...]
 	-f --finished     show when you can stop working given hours already
 	                  work; optional argument indicates span to calculate
 	                  hours over or start time; e.g., --finished
 	                  yesterday or --finished payperiod
 	--help            this usage screen
 houghton@NorthernSpy:~$ job to
 Monday,  7 March, 2011
   8:01 am - ongoing  1.33  bar, foo  something to add; and still more                                                                                                  
 
   TOTAL HOURS 1.33
   bar         1.33
   foo         1.33

=head1 DESCRIPTION

B<App::JobLog::Command::today> reviews the current day's events. In this it is completely equivalent to 
L<App::JobLog::Command::summary> given an option like C<today>, C<now>, or whatever might be the current date.

=head1 SEE ALSO

L<App::JobLog::Command::summary>, L<App::JobLog::Command::last>, L<App::JobLog::Command::tags>, L<App::JobLog::Command::configure>,
L<App::JobLog::Command::vacation>

=cut
