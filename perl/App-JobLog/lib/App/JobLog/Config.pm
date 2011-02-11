package App::JobLog::Config;
use App::JobLog::Constants qw(EDITOR DIRECTORY PRECISION PERIOD HOURS);
use Class::Autouse qw{
  File::HomeDir
  File::Spec
  Config::Tiny
  FileHandle
  App::JobLog::Command::info
};
use autouse 'File::Path' => qw(mkpath);
use autouse 'Cwd'        => qw(abs_path);
require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
  dir
  editor
  init_file
  log
  pay_period_length
  precision
  readme
  start_pay_period
  vacation
);
use Modern::Perl;

# manages configuration

# ensures that the working directory and the README file exist before
# we try to create or modify any files in the working directory
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

# working directory
my $dir;

sub dir {
    $dir ||= $ENV{ DIRECTORY() };
    $dir ||= File::Spec->catfile( File::HomeDir->my_home, '.joblog' );
    return $dir;
}

# log file
my $log;

sub log {
    $log ||= File::Spec->catfile( dir(), 'log' );
    return $log;
}

# readme file
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

# file recording vacation times
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

sub _config {
    unless ($config) {
        $config = Config::Tiny->new;
        my $f = _config_file();
        $config->read($f) if -e $f;
    }
    return $config;
}

sub precision {
    my ($value) = @_;
    return _param( 'precision', PRECISION(), $value );
}

sub day_length {
    my ($value) = @_;
    return _param( 'day-length', HOURS(), $value );
}

sub pay_period_length {
    my ($value) = @_;
    return _param( 'pay-period-length', PERIOD(), $value );
}

# returns DateTime representing start date of pay period or null if none is defined
sub start_pay_period {
    my ($value) = @_;
    require DateTime;
    if ( ref $value eq 'DateTime' ) {
        $value = sprintf '%d %d %d', $value->year, $value->month, $value->day;
    }
    $value = _param( 'start-pay-period', undef, $value );
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

sub _param {
    my ( $param, $default, $new_value ) = @_;
    my $config = _config();
    my $value  = $config->{all}->{$param};
    if ( defined $new_value ) {
        return $new_value if $new_value eq $default && !defined $value;
        return $value if defined $value && $value eq $new_value;
        $config_changed = 1;
        return $config->{all}->{$param} = $new_value;
    }
    else {
        return defined $value ? $value : $default;
    }
}

# editing program
sub editor {
    return $ENV{ EDITOR() };
}

1;
