package App::JobClock::Command::info;
use App::JobClock -command;
use Modern::Perl;
use autouse 'File::Temp' => qw(tempfile);
use autouse 'Pod::Usage' => qw(pod2usage);

sub execute {
    my ( $fh, $fn ) = tempfile( UNLINK => 1 );
    print $fh <<END;
=head1 Job Clock

This application allows one to keep a simple, human readable log
of one's activities. Job Clock also facilitates searching, summarizing,
and extracting information from this log as needed.

=head1 USAGE

=head1 ENVIRONMENT VARIABLES

=head1 HIDDEN DIRECTORY

=head1 DESCRIPTION

Author:    David Houghton
Copyright: 2011
License:   Perl

=cut
END
    $fh->close;
    pod2usage( -verbose => 2, -exitval => 0, -input => $fn );
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'describe job clock' }

1;
__END__

Job Clock

This application allows one to keep a simple, human readable log
of one's activities. Job Clock also facilitates searching, summarizing,
and extracting information from this log as needed.

explanation of use

environment variables

hidden directory

Author:    David Houghton
Copyright: 2011
License:   Perl
