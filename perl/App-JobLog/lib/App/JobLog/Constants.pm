package App::JobLog::Constants;

# ABSTRACT: a bunch of constants shared among modules; destined to be put in App::JobLog::Config

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(EDITOR DIRECTORY PRECISION PERIOD HOURS);

use Modern::Perl;

# Put these in their own module so they can be available in sub-modules.

# configuration

# default precision
use constant PRECISION => 2;

# default pay period
use constant PERIOD => 14;

# hours worked in day
use constant HOURS => 8;

# environment variables

# identifies text editor to use to edit log
use constant EDITOR => 'JOB_LOG_EDITOR';

# identifies directory to write files into
use constant DIRECTORY => 'JOB_LOG_DIRECTORY';

1;
