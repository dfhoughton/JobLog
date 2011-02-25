package App::JobLog::Command::summary;

# ABSTRACT: show what you did during a particular period

use App::JobLog -command;
use Modern::Perl;
use Class::Autouse 'App::JobLog::Log';
use autouse 'App::JobLog::TimeGrammar'   => qw(parse daytime);
use autouse 'Carp'                       => qw(carp);
use autouse 'Getopt::Long::Descriptive'  => qw(prog_name);
use autouse 'App::JobLog::Log::Format'   => qw(display time_remaining);
use autouse 'App::JobLog::Log::Synopsis' => qw(
  MERGE_ALL
  MERGE_ADJACENT
  MERGE_ADJACENT_SAME_TAGS
  MERGE_SAME_TAGS
  MERGE_SAME_DAY
  MERGE_SAME_DAY_SAME_TAGS
  NO_MERGE
);

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $tags          = $opt->{tag}         || [];
    my $excluded_tags = $opt->{exclude_tag} || [];
    my $match         = $opt->{match}       || [];
    my $no_match      = $opt->{no_match}    || [];
    my $time          = $opt->{time};

    # validate regexes, if any, while generating test

 # NOTE: using $opt->{x} form rather than $opt->x to facilitate invoking summary
 # from today command

    my $test = _make_test( $tags, $excluded_tags, $match, $no_match, $time );
    my $merge_level;
    given ( $opt->{merge} || '' ) {
        when ('no_merge') {
            $merge_level = NO_MERGE
        }
        when ('merge_all') {
            $merge_level = MERGE_ALL
        }
        when ('merge_adjacent') {
            $merge_level = MERGE_ADJACENT
        }
        when ('merge_adjacent_same_tags') {
            $merge_level = MERGE_ADJACENT_SAME_TAGS
        }
        when ('merge_same_tags') {
            $merge_level = MERGE_SAME_TAGS
        }
        when ('merge_same_day') {
            $merge_level = MERGE_SAME_DAY
        }
        when ('merge_same_day_same_tags') {
            $merge_level = MERGE_SAME_DAY_SAME_TAGS
        }
        default { $merge_level = MERGE_ADJACENT_SAME_TAGS }
    }

    # parse time expression
    my ( $start, $end ) = parse( join ' ', @$args );

    # collect synopses
    my $events = App::JobLog::Log->new->find_events( $start, $end );
    my $time_remaining = time_remaining($events);
    display $events unless $opt->{hidden};

    return $time_remaining;
}

# Construct a test from the tags, excluded-tags, match, no-match, and time options.
# The test determines what portion of what events are included in synopses.
sub _make_test {
    my ( $tags, $excluded_tags, $match, $no_match, $time ) = @_;

    my %tags          = map { $_ => 1 } @$tags;
    my %excluded_tags = map { $_ => 1 } @$excluded_tags;
    my @no_match = map { _re_test($_); qr/$_/ } @$no_match;
    my @match    = map { _re_test($_); qr/$_/ } @$match;
    $time = _parse_time($time);
    return undef unless %tags || %excluded_tags || @no_match || @match || $time;

    my $test = sub {
        my ($e) = @$_;
        if (%tags) {
            my $good = 0;
            for my $t ( $e->tags ) {
                $good = $tags{$t};
                last if $good;
            }
            return undef unless $good;
        }
        if (%excluded_tags) {
            my $bad = 0;
            for my $t ( $e->tags ) {
                $bad = $excluded_tags{$t};
                last if $bad;
            }
            return undef if $bad;
        }
        if ( @no_match || @match ) {
            my $good = !@match;
            for my $d ( @{ $e->data->description } ) {
                for my $re (@no_match) {
                    return undef if $d =~ $re;
                }
                unless ($good) {
                    for my $re (@match) {
                        $good = $d =~ $re;
                        last if $good;
                    }
                }
            }
            return undef unless $good;
        }
        if ($time) {
            my $s = $e->start->clone->set( %{ $time->{start} } );
            my $e = $e->end->clone->set( %{ $time->{end} } );
            return $e->overlap( $s, $e );
        }
        return $e;
    };
    return $test;
}

# look for regular expressions with side effects
sub _re_test {
    carp 'regex ' . $_[0] . '" appears to contain executable code'
      if $_[0] =~ /\(\?{1,2}{/;
}

# parse time expressions
our ( $b1, $b2 );
my $time_re = qr/
  ^ \s*+ (?&start) (?&end) \s*+ $
  (?(DEFINE)
    (?<start> (?&ba) | (?&time) )
    (?<ba> (?:(?&before)|(?&after)) \s*+)
    (?<before> (?: b(?:e(?:f(?:o(?:r(?:e)?)?)?)?)? | < ) (?{$b1 = 'before'}))
    (?<after> (?: a(?:f(?:t(?:e(?:r)?)?)?)? | > ) (?{$b1 = 'after'}))
    (?<time> (.*?) \s*+ - \s*+ (?{$b1 = $^N}))
    (?<end> (\S.*) (?{$b2 = $^N}))
  ) 
/xi;

sub _parse_time {
    my ($time) = @_;
    local ( $b1, $b2 );
    return unless $time;
    if ( $time =~ $time_re ) {
        my ( $t1, $t2 );
        given ($b1) {
            when ('before') {
                $t1 = {
                    hour     => 0,
                      minute => 0,
                      second => 0
                };
                $t2 = { daytime $b2 };
            }
            when ('after') {
                $t1 = {
                    daytime $b2
                };
                $t2 = {
                    hour   => 23,
                    minute => 59,
                    second => 59
                };
            }
            default {
                $t1 = {
                    daytime $b1
                };
                $t2 = { daytime $b2 };
            }
        }
        if (   $t2->{hour} < $t1->{hour}
            || $t2->{minute} < $t1->{minute}
            || $t2->{second} < $t1->{second} )
        {
            if ( $t2->{suffix} && $t2->{suffix} eq 'x' ) {
                $t2->{hour} += 12;
            }
            else {
                carp '"' . $time
                  . '" invalid time expression: endpoints out of order';
            }
        }
        delete $t1->{suffix}, delete $t2->{suffix};
        return { start => $t1, end => $t2 };
    }
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o <date or date range>' }

sub abstract { 'list tasks with certain properties in a particular time range' }

sub full_description {
    <<END
List events with certain properties in a particular time range. Only the portions
of events falling within the range will be listed.

Events may be filtered in numerous ways: by tag, time of day, or terms used in descriptions.
If tags to match are provided, only those events that contain at least one such tag will be shown. If
tags not to match are provided, only those events that contain none of these tags will be shown.

If you provide description filters to match or avoid, these will be interpreted as regexes. Try 'perldoc perlre'
for more details, or perhaps 'perldoc perlretut' (these will only work if you have the Perl documentation
installed on your machine). If you don't want to worry about regular expressions, simple strings will work.
Prefix your expression with '(?i)' to turn off case sensitivity. And don't enclose regexes in slashes or any other
sort of delimiter. Use 'ab', not '/ab/' or 'm!ab!', etc. Finally, you may need to enclose your regexes in quotes
to prevent the shell from trying to interpret them.

Time subranges may be of the form '11-12pm', '1am-12:30:15', 'before 2', 'after 6:12pm', etc. Either 'before'
or 'after' (or some prefix of these such as 'bef' or 'aft') may be followed by a time or you may use two time
expressions separated by a dash. The code will attempt to infer the precise time of ambiguous time expressions,
but it's best to be explicit. Case is ignored. Whitespace is optional in the expected places.

@{[__PACKAGE__->name]} provides many ways to consolidate events. These are the "merge" options. By default events
are grouped into days and within days into subgroups of adjacent events with the same tags. All the merge options
that require adjacency will also group by days but not vice versa. 
END
}

sub options {
    return (
        [
                "Use '@{[prog_name]} help "
              . __PACKAGE__->name
              . '\' to see full details.'
        ],
        [],
        [
            'tag|t=s@',
            'filter events to include only those with given tags; '
              . 'multiple tags may be specified'
        ],
        [
            'exclude-tag|T=s@',
            'filter events to exclude those with given tags; '
              . 'multiple tags may be specified'
        ],
        [
            'match|m=s@',
'filter events to include only those one of whose descriptions matches the given regex; '
              . 'multiple regexes may be specified'
        ],
        [
            'no-match|M=s@',
'filter events to include only those one of whose descriptions do not match the given regex; '
              . 'multiple regexes may be specified'
        ],
        [
            'time|i=s',
'consider only those portions of events that overlap the given time range'
        ],
        [
            "merge" => hidden => {
                one_of => [
                    [
                        "merge-all|mall|ma" =>
                          "glom all events into one synopsis"
                    ],
                    [ "merge-adjacent|madj" => "merge contiguous events" ],
                    [
                        "merge-adjacent-same-tags|mast" =>
"merge contiguous, identically-tagged events (default)"
                    ],
                    [
                        "merge-same-tags|mst" =>
                          "merge all identically tagged events"
                    ],
                    [
                        "merge-same-day|msd" =>
                          "merge all events in a given day"
                    ],
                    [
                        "merge-same-day-same-tags|msdst" =>
                          "merge all events in a given day"
                    ],
                    [ "no-merge|nm" => "keep all events separate" ],
                ]
            }
        ],
        [ 'hidden', 'display nothing', { hidden => 1 } ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('no time expression provided') unless @$args;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
