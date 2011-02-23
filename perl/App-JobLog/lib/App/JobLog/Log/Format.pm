package App::JobLog::Log::Format;

# ABSTRACT: pretty printer for log

=head1 DESCRIPTION

This module handles word wrapping, date formatting, and the like.

=cut

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(format);

use Modern::Perl;
use App::JobLog::Log;
use App::JobLog::Config qw(columns precision);
use Text::Wrap;

use constant TAG_COLUMN_LIMIT => 10;
use constant HOUR_IN_SECONDS  => 60 * 60;

my $duration_format = '%0.' . precision() . 'f';

=method format
Formats L<App::JobLog::Log::Synopsis> objects so they fit nicely on the screen.
=cut

sub format {
    my ( $start, $end, $merge_level, $test ) = @_;
    my $events = App::JobLog::Log->new->find_events( $start, $end );

    # TODO augment events with vacation and holidays
    if (@$events) {
        my @synopses = synopsis( $events, $merge_level, $test );

        my ( $format, $tag_width, $description_width ) =
          _define_format( \@synopses );
        my ($total, $previous_date, %tag_map) = 0;
        for my $s (@synopses) {
            # collect durations
            $total += $s->duration;
            $tag_map{$_} += $s->duration for $s->tags;
            if (
                !(
                    defined $previous_date
                    && _same_day( $previous_date, $s->date )
                )
              )
            {
                my $format =
                  !( defined $previous_date
                    && $previous_date->year == $s->date->year )
                  ? '%A, %e %B, %Y'
                  : '%A, %e %B';
                print $s->date->strftime($format), "\n";
            }
            $previous_date = $s->date;
            my @lines;
            push @lines, [ $s->time_fmt ] if $s->single_interval;
            push @lines, [ _duration( $s->duration ) ];
            push @lines, _wrap( $s->tag_string,  $tag_width );
            push @lines, _wrap( $s->description, $description_width );
            my $count = _pad_lines(\@lines);
            for my $i (0..$count) {
                printf $format, _gather(\@lines, $i);
            }
            print "\n";
        }
        my ($m1, $m2) = (length 'TOTAL HOURS', length _duration($total));
        for my $tag (keys %tag_map) {
            my $l = length $tag;
            $m1 = $l if $l > $m1;
        }
        $format = sprintf "%%-%ds %%%ds\n", $m1, $m2;
        printf $format, 'TOTAL HOURS', _duration($total);
        for my $key (sort keys %tag_map) {
            my $d = $tag_map{$key};
            printf $format, $key, _duration($d);
        }
    }
    else {
        say 'No events in interval specified.';
    }
}

# collect the pieces of columns corresponding to a particular line to print
sub _gather {
    my ($lines, $i) = @_;
    my @line;
    for my $column (@$lines) {
        push @line, $column->[$i];
    }
    return @line;
}

# add blank lines to short columns
# returns the number of lines to print
sub _pad_lines {
    my ($lines) = @_;
    my $max = 0;
    for my $column (@$lines) {
        $max = @$column if @$column > $max;
    }
    for my $column (@$lines) {
        push @$column, '' while @$column < $max;
    }
    return $max;
}

# whether two DateTime objects refer to the same day
sub _same_day {
    my ( $d1, $d2 ) = @_;
    return
         $d1->year == $d2->year
      && $d1->month == $d2->month
      && $d1->day == $d2->day;
}

# generate printf format for synopses
# returns format and wrap widths for tags and descriptions
sub _define_format {
    my $synopses = shift;

    #determine maximum width of each column
    my $widths;
    for my $s (@$synopses) {
        my $ts = $s->tag_string;
        if ( length $ts > TAG_COLUMN_LIMIT ) {
            my $wrapped = _wrap( $ts, TAG_COLUMN_LIMIT );
            $ts = '';
            for my $line (@$wrapped) {
                $ts = $line if length $line > length $ts;
            }
        }
        my $w = [
            $s->single_interval ? ( length $s->time_fmt ) : (),
            length _duration( $s->duration ),
            length $ts
        ];
        if ($widths) {
            for my $i ( 0 .. $#$widths ) {
                my ( $l1, $l2 ) = ( $w->[$i], $widths->[$i] );
                $widths->[$i] = $l1 if $l1 > $l2;
            }
        }
        else {
            $widths = $w;
        }
    }
    my $max_description = columns;

    # add on initial space to each column
    $widths = [ map { $_ + 2 } @$widths ];
    for my $c (@$widths) {
        $max_description -= $c;    # column width
    }
    $max_description -= 2;         # tab before text
    my $format;
    if ( @$widths == 3 ) {

        # print times
        $format = sprintf "%%%ds%%%ds%%-%ds%%-%ds\n", @$widths,
          $max_description;
    }
    else {

        # don't print times
        $format = sprintf "%%%ds%%-%ds%%-%ds\n", @$widths, $max_description;
    }
    return $format, $widths->[$#$widths], $max_description;
}

sub _duration { sprintf $duration_format, $_[0] / HOUR_IN_SECONDS }

# wraps Text::Wrap::wrap
sub _wrap {
    my ( $text, $columns ) = @_;
    $Text::Wrap::columns = $columns;
    my $s = wrap( '', '', $text );
    my @ar = $s =~ /^.*$/mg;
    return \@ar;
}

1;
