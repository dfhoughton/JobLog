package App::JobClock::Constants;

$VERSION = 0.2;

# Put these in their own module so they can be available in sub-modules.
#
# David Houghton, 20 July 2006

use Exporter::Tidy
  default  => [qw(:all)],
  standard => [
    qw(
    NAME 
    TIME 
    GRANT 
    DESCRIPTION 
    OPEN 
    NON_LOG 
    IN 
    BEFORE 
    AFTER 
    LOGNAME 
    LASTTASK 
    CONFIG 
    STARTING 
    UNCLASSIFIED)
  ],
  grants   => [qw(UNCLASSIFIED HOLIDAY VACATION)],
  messages => [
    qw(
       BEGAN_AT
       DONE_FOR_DAY
       EMPTY_RANGE
       LAST_DESCRIPTION
       LAST_FUND
       NONE_OPEN
       NO_DESCRIPTION
       NO_RECORD
       REMAINING
       STARTING
       TOTAL_HOURS
       UNCLASSIFIED_DOCUMENTS
       WHEN_DONE
       )
  ],
  configuration => [qw(PRECISION PERIOD HOURS FIXED_YEAR)];

# if you change the script name, change the following
# NOTE: the usage information must be updated by hand
use constant NAME => 'clock';

# indices into last_time array
use constant TIME        => 0;
use constant GRANT       => 1;
use constant DESCRIPTION => 2;
use constant OPEN        => 3;

# constants used only in this routine test_line and code that uses it
use constant NON_LOG => 0;
use constant IN      => 1;
use constant BEFORE  => 2;
use constant AFTER   => 3;

# file names
use constant LOGNAME  => 'log';
use constant LASTTASK => 'last';
use constant CONFIG   => 'config';

# default precision
use constant PRECISION => 2;

# default pay period
use constant PERIOD => 14;

# hours worked in day
use constant HOURS => 8;

# year of dates repeated in every year
use constant FIXED_YEAR => 2000;

# symbol in log for task with no specified funding source
use constant UNCLASSIFIED => '???';

# symbol in log and summaries for vacation days
use constant VACATION => 'vacation';

# symbol in log for holidays
use constant HOLIDAY => 'holiday';

# starting up message
use constant STARTING => 'starting up';

# no description message
use constant NO_DESCRIPTION => 'NO DESCRIPTION';

# display label for total time clocked
use constant TOTAL_HOURS => 'TOTAL HOURS';

# display label for time due minus time clocked
use constant REMAINING => 'REMAINING';

# message returned when range summarized is empty
use constant EMPTY_RANGE => 'no tasks found in range specified';

# message returned when no more work need be done in the day
use constant WHEN_DONE => 'done at';

# message appearing before finish time
use constant DONE_FOR_DAY => 'you were done at';

# message when --last is requested but last file is not found
use constant NO_RECORD => 'no record of last task';

# one of the --last messages
use constant BEGAN_AT => 'The current task began at';

# one of the --last messages
use constant NONE_OPEN => 'No task is currently open.';

# one of the --last messages
use constant LAST_FUND => 'Last funding source recorded';

# one of the --last messages
use constant LAST_DESCRIPTION => 'Last description recorded';

# message appearing when unclassified tasks remain when fund
# summary is created
use constant UNCLASSIFIED_DOCUMENTS => 'tasks remaining unclassified: ';

1;
