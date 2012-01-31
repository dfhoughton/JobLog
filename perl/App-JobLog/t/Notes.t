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

subtest 'append and retrieve last note' => sub {
    my $log = App::JobLog::Log->new;
    is(
        exception {
            $log->append_note( description => 'foo' );
        },
        undef,
        'no error thrown when appending note'
    );
    is(
        exception {
            my $ll = $log->last_note;
            ok(defined $ll, 'retrieved note');
            is(@{$ll->data->description}, 1, 'got single line in note description');
            is($ll->data->description->[0], 'foo', 'got same description back that was put in');
            $log->append_note(description=>'bar', tags=>['quux']);
            $ll = $log->last_note;
            is($ll->data->description->[0], 'bar', 'got correct description back for second note');
            is($ll->data->tags->[0], 'quux', 'got tag back');
    my $date =
      DateTime->new( year => 2011, month => 1, day => 1, time_zone => tz );
            $log->append_event( description => 'test event' );
            $ll = $log->last_note;
            is($ll->data->description->[0], 'bar', 'found last note correctly when there was an intervening event');
        },
        undef,
        'no error thrown when retrieving last note'
    );
};

done_testing();
