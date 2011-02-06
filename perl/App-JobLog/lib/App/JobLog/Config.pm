package App::JobClock::Config;
use App::JobClock::Constants;
use Modern::Perl;
use Class::Autouse qw{File::HomeDir File::Spec Config::Tiny FileHandle};
use autouse 'File::Path' => qw(mkpath);
use autouse 'Cwd'        => qw(abs_path);

# manages configuration

# ensures that the working directory and the README file exist before
# we try to create or modify any files in the working directory
sub init_file {
    my ( undef, $path ) = @_;
    unless ( -e $path ) {
        my ( $volume, $directories, $file ) = File::Spec->splitpath($path);
        my $dir = File::Spec->catfile( $volume, $directories );
        mkpath( $dir, { verbose => 0, mode => 0711 } ) unless -d $dir;
        unless ( -e readme() ) {
            my $fh = FileHandle->new( readme(), 'w' )
              or die 'could not create file ' . readme();
            my $executable = abs_path($0);

            # to protect against refactoring
            my $command = App::JobClock::Command::info->name;
            print $fh <<END;

Job Clock

This directory holds files used by Job Clock to maintain
a work log. For more details type

$executable $command

on the command line.

END
            $fh->close;
        }
    }
}

# working directory
our $dir;

sub dir {
    $dir ||= $ENV{ DIRECTORY() };
    $dir ||= File::Spec->catfile( File::HomeDir->my_home, '.jobclock' );
    return $dir;
}

# log file
our $log;

sub log {
    $log ||= File::Spec->catfile( dir(), 'log' );
    return $log;
}

# readme file
our $readme;

sub readme {
    $readme ||= File::Spec->catfile( dir(), 'README' );
    return $readme;
}

# configuration file for basic parameters
our $config_file;

sub _config_file {
    $config_file ||= File::Spec->catfile( dir(), 'config.ini' );
    return $config_file;
}

# file recording vacation times
our $vacation_file;

sub vacation {
    $vacation_file ||= File::Spec->catfile( dir(), 'vacation' );
    return $vacation_file;
}

# configuration object and whether any changes need to be written to this file
our ( $config, $config_changed );

END {
    if ($config_changed) {
        __PACKAGE__->init_file( _config_file() );
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
    my ( undef, $value ) = @_;
    return _param( 'precision', PRECISION, $value );
}

sub day_length {
    my ( undef, $value ) = @_;
    return _param( 'day-length', HOURS, $value );
}

sub pay_period_length {
    my ( undef, $value ) = @_;
    return _param( 'pay-period-length', PERIOD, $value );
}

# returns DateTime representing start date of pay period or null if none is defined
sub start_pay_period {
    my ( undef, $value ) = @_;
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
    return $ENV{EDITOR()};
}

1;
