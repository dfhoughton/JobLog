package App::JobLog::Config;

# ABSTRACT: central depot for App::JobLog configuration parameters and controller allowing their modification

=head1 DESCRIPTION

C<App::JobLog::Config> is a central repository for program state that may be conserved from
session to session. It also serves as a general interface between the program and the machine.

This wasn't written to be used outside of C<App::JobLog>. 

=cut

use Exporter 'import';
our @EXPORT_OK = qw(
  columns
  dir
  editor
  init_file
  log
  pay_period_length
  precision
  readme
  start_pay_period
  sunday_begins_week
  vacation
  DIRECTORY
  EDITOR
  HOURS
  PERIOD
  PRECISION
);

use Class::Autouse qw{
  File::HomeDir
  File::Spec
  Config::Tiny
  FileHandle
  App::JobLog::Command::info
};
use autouse 'File::Path'    => qw(mkpath);
use autouse 'Cwd'           => qw(abs_path);
use autouse 'Term::ReadKey' => qw(GetTerminalSize);
use Modern::Perl;

# default precision
use constant PRECISION => 2;

# default pay period
use constant PERIOD => 14;

# hours worked in day
use constant HOURS => 8;

# whether Sunday is the first day of the week
# otherwise it's Monday, as in DateTime
use constant SUNDAY_BEGINS_WEEK => 1;

# environment variables

# identifies text editor to use to edit log
use constant EDITOR => 'JOB_LOG_EDITOR';

# identifies directory to write files into
use constant DIRECTORY => 'JOB_LOG_DIRECTORY';

=method init_file

C<init_file> manages configuration files. It ensures that the 
working directory and the README file exist before
we try to create or modify any files in the working directory.

=cut

sub init_file {
    my ($path) = @_;
    unless ( -e $path ) {
        my ( $volume, $directories, $file ) = File::Spec->splitpath($path);
        my $dir = File::Spec->catfile( $volume, $directories );
        mkpath( $dir, { verbose => 0, mode => 0711 } ) unless -d $dir;
        unless ( -e readme() ) {
            my $fh = FileHandle->new( readme(), 'w' )
              or die 'could not create file ' . readme();
            my $executable = abs_path($0);

            # to protect against refactoring
            my $command = App::JobLog::Command::info->name;
            print $fh <<END;

Job Log

This directory holds files used by Job Log to maintain
a work log. For more details type

$executable $command

on the command line.

END
            $fh->close;
        }
    }
}

=method dir

Working directory.

=cut

my $dir;

sub dir {
    $dir ||= $ENV{ DIRECTORY() };
    $dir ||= File::Spec->catfile( File::HomeDir->my_home, '.joblog' );
    return $dir;
}

=method log

Log file.

=cut

my $log;

sub log {
    $log ||= File::Spec->catfile( dir(), 'log' );
    return $log;
}

=method readme

README file.

=cut

my $readme;

sub readme {
    $readme ||= File::Spec->catfile( dir(), 'README' );
    return $readme;
}

# configuration file for basic parameters
my $config_file;

sub _config_file {
    $config_file ||= File::Spec->catfile( dir(), 'config.ini' );
    return $config_file;
}

=method vacation

Obtain the file in which vacation information is stored.

=cut

my $vacation_file;

sub vacation {
    $vacation_file ||= File::Spec->catfile( dir(), 'vacation' );
    return $vacation_file;
}

# configuration object and whether any changes need to be written to this file
my ( $config, $config_changed );

END {
    if ($config_changed) {
        init_file( _config_file() );
        $config->write( _config_file() );
    }
}

# construct configuration object as necessary
sub _config {
    unless ($config) {
        $config = Config::Tiny->new;
        my $f = _config_file();
        $config->read($f) if -e $f;
    }
    return $config;
}

=method precision

Obtain the number of decimal places represented when displaying the duration
of events.

=cut

sub precision {
    my ($value) = @_;
    return _param( 'precision', PRECISION, 'summary', $value );
}

=method day_length

The number of hours one is expected to work in a day.

=cut

sub day_length {
    my ($value) = @_;
    return _param( 'day-length', HOURS, 'time', $value );
}

=method pay_period_length

The number of days between paychecks.

=cut

sub pay_period_length {
    my ($value) = @_;
    return _param( 'pay-period-length', PERIOD, 'time', $value );
}

=method sunday_begins_week

Whether to regard Sunday or Monday as the first day in the week
when interpreting time expressions such as 'last week'. L<DateTime>
uses Monday. The default for L<App::JobLog> is Sunday. For the purposes
of calculating hours worked this will make no difference for most people.

=cut

sub sunday_begins_week {
    my ($value) = @_;
    return _param( 'sunday-begins-week', SUNDAY_BEGINS_WEEK, 'time', $value );
}

=method start_pay_period

Returns DateTime representing start date of pay period or null if none is defined.

=cut

sub start_pay_period {
    my ($value) = @_;
    require DateTime;
    if ( ref $value eq 'DateTime' ) {
        $value = sprintf '%d %d %d', $value->year, $value->month, $value->day;
    }
    $value = _param( 'start-pay-period', undef, 'time', $value );
    if ($value) {
        my @parts = split / /, $value;
        return DateTime->new(
            year  => $parts[0],
            month => $parts[1],
            day   => $parts[2]
        );
    }
    return undef;
}

# abstracts out code for maintaining config file
sub _param {
    my ( $param, $default, $section, $new_value ) = @_;
    $section ||= 'main';
    my $config = _config();
    my $value  = $config->{$section}->{$param};
    if ( defined $new_value ) {
        if ( defined $default && $new_value eq $default && !defined $value ) {
            return $new_value;
        }
        return $value if defined $value && $value eq $new_value;
        $config_changed = 1;
        return $config->{$section}->{$param} = $new_value;
    }
    else {
        return defined $value ? $value : $default;
    }
}

=method editor

Log editing program.

=cut

sub editor {
    return $ENV{ EDITOR() };
}

=method columns

The number of columns available in the terminal. This defaults to
76 when L<Term::ReadKey> is unable to determine terminal width.

=cut

sub columns {
    my ($cols) = GetTerminalSize;
    $cols ||= 76;
    return $cols;
}

1;
