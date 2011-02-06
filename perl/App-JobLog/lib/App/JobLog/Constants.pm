package App::JobLog::Constants;
use Modern::Perl;

# Put these in their own module so they can be available in sub-modules.

use Exporter::Tidy
  default       => [qw(:all)],
  env_vars      => [qw(EDITOR DIRECTORY)],
  configuration => [qw(PRECISION PERIOD HOURS)];

# configuration

# default precision
use constant PRECISION => 2;

# default pay period
use constant PERIOD => 14;

# hours worked in day
use constant HOURS => 8;

# environment variables

# identifies text editor to use to edit log
use constant EDITOR => 'JOB_CLOCK_EDITOR';

# identifies directory to write files into
use constant DIRECTORY => 'JOB_CLOCK_DIRECTORY';

1;
