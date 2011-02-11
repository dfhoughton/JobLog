#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use File::Temp ();
use App::JobLog::Constants qw(DIRECTORY);
use App::JobLog::Config qw(log);
use App::JobLog::Log::Line;
use App::JobLog::Log;
use DateTime;
use File::Spec;
use IO::All -utf8;

use Test::More;

# create a working directory
my $dir = File::Temp->newdir();
$ENV{ DIRECTORY() } = $dir;

for my $size (qw(tiny small normal big)) {

    # copy log data over
    my $file = File::Spec->catfile( 'data', "$size.log" );
    my $io = io $file;
    $io > io log;

    # determine which dates are present in the log
    # obtain tags and description for first and last events
    my ( @dates, %dates, $first, $last );
    while ( my $line = $io->getline ) {
        chomp $line;
        if ( $line =~ /^(\d{4})\s++(\d++)\s++(\d++)/ ) {
            my $ll = App::JobLog::Log::Line->parse($line);
            if ( $ll->is_beginning ) {
                $first = $ll unless $first;
                $last = $ll;
            }
            my $ts = sprintf '%d/%02d/%02d', $1, $2, $3;
            unless ( $dates{$ts} ) {
                my $date = DateTime->new( year => $1, month => $2, day => $3 );
                $dates{$ts} = 1;
                push @dates, $date;
            }
        }
    }

    # test log
    subtest "$size log" => sub {
        my $log = App::JobLog::Log->new;
        my ($e) = $log->first_event;
        my $ts1 = join ' ', @{ $first->tags };
        my $ts2 = join ' ', @{ $e->tags };
        is( $ts1, $ts2, "found tags of first event correctly for $size log" );
        ($e) = $log->last_event;
        $ts1 = join ' ', @{ $last->tags };
        $ts2 = join ' ', @{ $e->tags };
        is( $ts1, $ts2, "found tags of last event correctly for $size log" );
        ok( !( $last->is_beginning ^ $e->is_open ),
            "correctly determined whether last event in log is ongoing" );

        for (
            my $d = $dates[0]->clone ;
            DateTime->compare( $d, $dates[$#dates] ) <= 0 ;
            $d = $d->add( days => 1 )
          )
        {
            my $ts  = $d->strftime('%Y/%m/%d');
            my $end = $d->clone;
            $end->add( days => 1 )->subtract( seconds => 1 );
            my $events = $log->find_events( $d, $end );
            if ( $dates{$ts} ) {
                ok( @$events, 'found events' );
                my $e = $events->[-1];
                if ($e) {
                    my $tags = $e->tags;
                    ok( ref $tags eq 'ARRAY', 'obtained tags' );
                    if ($tags) {
                        ok( @$tags, 'tags found for event' );
                        unless ( $tags->[0] == @$events ) {
                            print $ts, ' found ',
                              scalar(@$events) . ' wanted ' . $tags->[0] . "\n";
                            print $_->data, "\n" for @$events;
                        }
                        ok( $tags->[0] == @$events,
                            'correct number of events for day' );
                    }
                }
                else {
                    fail('event is undefined');
                }
            }
            else {
                unless ( @$events == 0 ) {
                    print $ts, "\n";
                }
                ok( @$events == 0, 'day absent from log contains no events' );
            }
        }
    };
}

done_testing();
