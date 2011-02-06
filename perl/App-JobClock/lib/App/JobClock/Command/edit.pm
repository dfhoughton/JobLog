package App::JobClock::Command::edit;
use App::JobClock -command;
use Modern::Perl;
use Class::Autouse qw{
  App::JobClock::Config
  App::JobClock::Log::Line
  FileHandle
};
use autouse 'File::Temp'  => qw(tempfile);
use autouse 'File::Copy'  => qw(copy);
use autouse 'Digest::MD5' => qw(md5);

sub execute {
    my ( $self, $opt, $args ) = @_;
    if ( my $editor = App::JobClock::Config->editor ) {
        if ( my $log = App::JobClock::Config->log ) {
            my ( $fh, $fn ) = tempfile;
            binmode $fh;
            copy( $log, $fh );
            $fh->close;
            $fh = FileHandle->new($log);
            my $md51 = md5($fh);
            system "$editor $log";
            $fh = FileHandle->new($log);
            my $md52 = md5($fh);

            if ( $md51 ne $md52 ) {
                $fh = FileHandle->new( "$log.bak", 'w' );
                copy( $fn, $fh );
                $fh->close;
                _verify($log);
            }
            else {
                unlink $fn;
            }
        }
        else {
            print STDERR "nothing in log to edit\n";
        }
    }

    print "(edit) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name }

sub abstract { 'open a text editor to edit the log' }

sub overview {
    return (
        [ abstract() ],
        [
'checks log syntax after saving, commenting out ill-formed lines and printing a warning'
        ],
        [
'requires the preferred editor to have been specified; see configure command'
        ],
    );
}

# check to make sure log is consistent and comment out any events that are not consistent
sub _verify {
    my $log   = shift;
    # my $logh  = FileHandle->new($log);
    # my $temph = FileHandle->new my $previous;
    # my @lines = map {
        # if    (/^\s*+(?:#.*)$/)                                    { $_ }
        # elsif (/(?:(\d{4}) (\d++) (\d++) (\d++) (\d++) (\d++))()/) { }
        # else { "# CANNOT PARSE NEXT LINE\n#$_" }
    # } <$logh>;
}

1;
