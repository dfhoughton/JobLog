#!/usr/bin/perl

use 5.006;
use strict;
use warnings;
use autodie;

use File::Path qw(remove_tree);
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

subtest 'append and retrieve last note' => sub {
    my $log = App::JobLog::Log->new;
    is(
        exception {
            $log->append_note( description => 'foo' );
            is(
                exception {
                    my ($ll) = $log->last_note;
                    if ( defined $ll ) {
                        ok( 1, 'retrieved note' );
                        is( @{ $ll->data->description },
                            1, 'got single line in note description' );
                        is( $ll->data->description->[0],
                            'foo',
                            'got same description back that was put in' );
                        $log->append_note(
                            description => 'bar',
                            tags        => ['quux']
                        );
                        ($ll) = $log->last_note;
                        is( $ll->data->description->[0],
                            'bar',
                            'got correct description back for second note' );
                        is( $ll->data->tags->[0], 'quux', 'got tag back' );
                        my $date = DateTime->new(
                            year      => 2011,
                            month     => 1,
                            day       => 1,
                            time_zone => tz
                        );
                        $log->append_event( description => 'test event' );
                        ($ll) = $log->last_note;
                        is( $ll->data->description->[0], 'bar',
'found last note correctly when there was an intervening event'
                        );
                    }
                },
                undef,
                'no error thrown when retrieving last note'
            );
        },
        undef,
        'no error thrown when appending note'
    );
};

subtest 'parsing a log' => sub {

    # make a log
    <<END > io log;
# 2011/01/01
2011  1  1  2 22 30<NOTE>:first note
2011  1  1  2 23 30::foo
2011  1  1  3 32 33:DONE
2011  1  1  4 14 15::bar
2011  1  1  8 56  0::baz
2011  1  1 12 47 25:DONE
2011  1  1 13 43  4::quux
2011  1  1 18  6 17::and so forth
2011  1  1 18  6 18<NOTE>:last note
2011  1  1 22 10 49:DONE
END

    # count events
    my $log = App::JobLog::Log->new;
    my ($note) = $log->last_note;
    note $note;
    is( $note->data->description->[0], 'last note', 'found last note' );
    my ($e) = $log->first_event;
    is( $e->data->description->[0], 'foo', 'found first event' );
    is( $e->start->minute,          23,    'correct start time' );
    my $s = $e->start;
    ($e) = $log->last_event;
    is( $e->start->second, 17, 'correct start time for last event' );
    my $events = $log->find_events( $s, $e->end );
    is( scalar(@$events), 5, 'found correct number of events' );
};

subtest 'searching for notes' => sub {
    note('got to write these');
    ok(1);
};

done_testing();

remove_tree $dir;
