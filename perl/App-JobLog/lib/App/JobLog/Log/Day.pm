package App::JobLog::Log::Day;

# ABSTRACT: collects events and vacation in a complete day

=head1 DESCRIPTION

C<App::JobLog::Log::Day> gathers all the events occurring in a particular day
to see how much vacation time applies.

=cut

use Modern::Perl;
use App::JobLog::Config qw(
  day_length
  is_workday
  precision
);
use Carp qw(carp);
use Text::Wrap;
use App::JobLog::Log::Format qw(
  duration
  wrap
);

use constant WORK_SECONDS => 60 * 60 * day_length;

=method new

Your basic constructor. It can be called on the class or an instance.

=cut

sub new {
    my ( $class, %opts ) = @_;
    $class = ref $class || $class;
    bless { events => [], vacation => [], synopses => [], %opts }, $class;
}

sub start { $_[0]->{start} }

sub end { $_[0]->{end} }

=method skip_flex

Whether this days is ignoring flex time.

=cut

sub skip_flex { $_[0]->{skip_flex} }

=method time_remaining

Determines how much work was done this day relative to what was expected.

=cut

sub time_remaining {
    my ($self) = @_;
    my $t = 0;
    $t -= $_->duration for @{ $self->events }, @{ $self->vacation };
    $t += WORK_SECONDS if is_workday $self->start;
    return $t;
}

=method events

Returns reference to list of events occurring in this day. These are work
events, not vacation.

=cut

sub events { $_[0]->{events} }

=method vacation

Returns reference to list of vacation events occurring in this day.

=cut

sub vacation { $_[0]->{vacation} }

=method synopses

Returns reference to list of L<App::JobLog::Log::Synopsis> objects.

=cut

sub synopses { $_[0]->{synopses} }

=method is_empty

Whether period contains neither events nor vacation .

=cut

sub is_empty {
    my ($self) = @_;
    return !( @{ $self->events } || @{ $self->vacation } );
}

sub show_date { !$_[0]->no_date }

sub no_date { $_[0]->{no_date} }

=method times

Count up the amount of time spent in various ways this day.

=cut

sub times {
    my ( $self, $times ) = @_;

    for my $e ( @{ $self->events }, @{ $self->vacation } ) {
        my @tags = @{ $e->tags };
        my $d    = $e->duration;
        $times->{tags}{$_} += $d for @tags;
        $times->{untagged} += $d unless @tags;
        $times->{total} += $d;
        $times->{vacation} += $d if $e->isa('App::JobLog::Vacation::Period');
    }
    $times->{expected} += WORK_SECONDS
      if is_workday $self->start;
}

=method display

C<display> expects a previous day object, or C<undef> if there is no such object,
a format specifying column widths, a hash reference containing various
pieces of formatting information, and the screen width -- -1 means do not wrap.

It prints a report of the events of the day
to STDOUT.

=cut

sub display {
    my ( $self, $previous, $format, $columns, $screen_width ) = @_;
    return if $self->is_empty;

    # cache some bits from the $columns hash
    my ( $show_times, $show_durations, $show_tags, $show_descriptions ) =
      @{ $columns->{formats} }{qw(time duration tags description)};
    my $show_date = $columns->{date};
    my ( $tag_width, $description_width ) =
      @{ $columns->{widths} }{qw(tags description)};

    # date
    if ($show_date) {
        my $f =
          !( $previous && $previous->start->year == $self->start->year )
          ? '%A, %e %B, %Y'
          : '%A, %e %B';
        print $self->start->strftime($f), "\n";
    }

    # activities
    for my $s ( @{ $self->synopses } ) {
        my @lines;
        push @lines, [ $s->time_fmt ] if $show_times;
        push @lines, [ duration( $s->duration ) ] if $show_durations;
        push @lines, wrap( $s->tag_string, $tag_width ) if $show_tags;
        push @lines, $screen_width == -1
          ? [ $s->description ]
          : wrap( $s->description, $description_width )
          if $show_descriptions;
        my $count = _pad_lines( \@lines );

        for my $i ( 0 .. $count ) {
            say sprintf $format, _gather( \@lines, $i );
        }
    }
    print "\n"
      if $show_times
          || $show_durations
          || $show_tags
          || $show_descriptions
          || $show_date;
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
    return $max - 1;
}

# collect the pieces of columns corresponding to a particular line to print
sub _gather {
    my ( $lines, $i ) = @_;
    my @line;
    for my $column (@$lines) {
        push @line, $column->[$i];
    }
    return @line;
}

=method pseudo_event

Generates an L<App::JobLog::Log::Event> that encapsulates the interval of the day.

=cut

sub pseudo_event {
    my ($self) = @_;
    unless ( $self->{pseudo_event} ) {
        my $e =
          App::JobLog::Log::Event->new(
            App::JobLog::Log::Line->new( time => $self->start ) );
        $e->end = $self->end;
        $self->{pseudo_event} = $e;
    }
    return $self->{pseudo_event};
}

1;
