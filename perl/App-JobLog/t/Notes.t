#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use autodie;

use File::Temp ();
use App::JobLog::Config qw(log DIRECTORY);
use App::JobLog::Log::Line;
use App::JobLog::Log;
use App::JobLog::Time qw(tz);
use DateTime;
use File::Spec;
use IO::All -utf8;
use FileHandle;

use Test::More;
use Test::Fatal;

# create a working directory
my $dir = File::Temp->newdir();
$ENV{ DIRECTORY() } = $dir;

# use a constant time zone so as to avoid crafting data to fit various datelight savings time adjustments
$App::JobLog::Config::tz =
  DateTime::TimeZone->new( name => 'America/New_York' );

subtest 'empty log' => sub {
    my $log = App::JobLog::Log->new;
    my $date =
      DateTime->new( year => 2011, month => 1, day => 1, time_zone => tz );
    my $end = $date->clone->add( days => 1 )->subtract( seconds => 1 );
    is(
        exception {
            my $events = $log->find_events( $date, $end );
            ok( @$events == 0, 'no events in empty log' );
        },
        undef,
        'no error thrown with empty log',
    );
    is(
        exception {
            $log->append_event( time => $date, description => 'test event' );
            $log->close;
            my $events = $log->find_events( $date, $end );
            ok( @$events == 1, 'added event appears in empty log' );
        },
        undef,
        'added event to empty log'
    );
    $log = App::JobLog::Log->new;
    my $events = $log->find_events( $date, $end );
    ok( @$events == 1, 'event preserved after closing log' );
};

done_testing();
