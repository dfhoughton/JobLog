#!/usr/bin/perl

# tests App::JobLog::TimeGrammar

use Modern::Perl;

use App::JobLog::Config qw(start_pay_period pay_period_length);
use App::JobLog::TimeGrammar;
use DateTime;

use Test::More;
use Test::Fatal;

# fix current moment
my $now = DateTime->new( year => 2011, month => 2, day => 18 );
App::JobLog::TimeGrammar->present_date = $now;

subtest 'single dates with times' => sub {
    my %dates = (
        'Thursday'    => [ [ 8, 30 ], [ 2011, 2, 17 ] ],
        'last Friday' => [ [ 8, 30 ], [ 2011, 2, 11 ] ],
        '2/1'         => [ [ 8, 30 ], [ 2011, 2, 1 ] ],
        '2010/2/1'    => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
        '2010.2.1'    => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
        '2/1/2010'    => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
        '2.1.2010'    => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
        'Feb 1, 2010' => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
        '1 Feb, 2010' => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
        '1 Feb 2010'  => [ [ 8, 30 ], [ 2010, 2, 1 ] ],
    );
    my @variants;
    while ( my ( $expression, $times ) = each %dates ) {
        my @time = @{ $times->[0] };
        push @variants, [ $_, [ @{ $times->[1] }, @{ $times->[0] } ] ]
          for time_variants( $expression, @time );
    }
    plan tests => 3 * @variants;
    for my $variant (@variants) {
        my $expression = $variant->[0];
        my ( $s, $e, $is_interval ) = parse($expression);
        ok( time_test( $s, $variant->[1] ), "right time for '$expression' " );
        ok( !$is_interval, " determined '$expression' is not an interval " );
        ok(
            $e->hour == 23 && $e->minute == 59 && $e->second == 59,
            "inferred end time for '$expression' correctly "
        );
    }
};

done_testing();

sub time_test {
    my ( $date, $ar ) = @_;
    my $i = 0;
    for my $key (qw(year month day hour minute)) {
        return 0 if $date->$key != $ar->[ $i++ ];
    }
    return 1;
}

# add time to date expression in various ways
sub time_variants {
    my ( $expression, @time ) = @_;
    my @variants = map {
        (
            "at $_ on $expression",
            "$_ on $expression",
            "$expression at $_",
            "${expression}at$_",
            "$expression $_",
          )
    } clock_time_variants(@time);
    @variants = map {
        if (/at/) { ( my $v = $_ ) =~ s/at/@/; $_, $v }
        else      { $_ }
    } @variants;
    return @variants;
}

# produces a fairly thorough subset of the ways one can express a particular
# clock time
sub clock_time_variants {
    my ( $hour, $minute ) = @_;
    my $h = $hour == 0 ? 12 : $hour;
    my @base = ( sprintf '%d:%02d', $h, $minute );
    push @base, $h unless $minute;
    my @variants = $hour ? @base : ();
    my @suffixes =
      map { $_ . 'm', "$_.m.", "${_}m", "$_.m." } ( $hour < 12 ? 'a' : 'p' );
    my @hours = $hour < 13 ? ($h) : ( $h, $h - 12 );
    @hours =
      map { sprintf( '%d:%02d', $_, $minute ), $minute ? () : $_ } @hours;

    for my $base (@hours) {
        for my $suffix (@suffixes) {
            push @variants, $base . $suffix;
        }
    }

    return @variants;
}
