package App::JobLog::Vacation;

# ABSTRACT: controller for the vacation model

=head1 DESCRIPTION

Code to manage vacation times.

=cut

use Modern::Perl;
use App::JobLog::Vacation::Period;
use App::JobLog::Config qw(
  vacation
  init_file
);
use Carp qw(carp);
use FileHandle;

=method new

Initializes C<App::JobLog::Vacation> object from file.

=cut

sub new {
    my $class = shift;
    $class = ref $class if ref $class;
    my $self = bless { changed => 0 }, $class;
    if ( -e vacation ) {
        my $fh = FileHandle->new(vacation);
        my @data;
        while ( my $line = <$fh> ) {
            chomp $line;
            my $v = App::JobLog::Vacation::Period->parse($line);
            push @data, $v;
        }
        $self->{data} = [ sort { $a->cmp($b) } @data ];
    }
    return $self;
}

=method periods

Returns sorted list of vacation periods.

=cut

sub periods { @{ $_[0]->{data} || [] } }

=method close

Save any changes to vacation file.

=cut

sub close {
    my ($self) = @_;
    if ( $self->{changed} ) {
        $self->{changed} = 0;
        if ( @{ $self->{data} } ) {

            # something to save
            init_file(vacation) unless -e vacation;
            my $fh = FileHandle->new( vacation, 'w' );
            for my $v ( @{ $self->{data} } ) {
                print $fh $v, "\n";
            }
            $fh->close;
        }
        elsif ( -e vacation ) {
            unlink(vacation);
        }
    }
}

# make sure changes are written to the file
sub DESTROY {
    my ($self) = @_;
    $self->close if $self->{changed};
}

=method add

Add a new vacation period to file.

=cut

sub add {
    my ( $self, %opts ) = @_;
    my ( $end, $type, $repeats ) = @opts{qw(end type repeats)};
    delete @opts{qw(end type repeats)};
    my $ll = App::JobLog::Log::Line->new(%opts);
    my $v  = App::JobLog::Vacation::Period->new(
        $ll,
        end     => $end,
        type    => $type,
        repeats => $repeats
    );
    my @data = @{ $self->{data} || [] };

    for my $other (@data) {
        if ( $other->conflicts($v) ) {
            my $d1 = join ' ', $v->parts;
            my $d2 = join ' ', $other->parts;
            carp "$d1 conflicts with existing period $d2";
        }
    }
    push @data, $v;
    $self->{data} = [ sort { $a->cmp($b) } @data ];
    $self->{changed} = 1;
}

=method remove

Remove a particular vacation time, identified by index, from vacation file.

=cut

sub remove {
    my ( $self, $index ) = @_;
    carp 'vacation date index must be non-negative' if $index < 0;
    my $data = $self->{data};
    carp "unknown vacation index: $index" unless $data && @$data >= $index;
    splice @$data, $index - 1, 1;
    $self->{changed} = 1;
}

=method show

Produces pretty list of vacation times.

=cut

sub show {
    my ($self) = @_;
    my @parts;
    my $widths;
    for my $v ( $self->periods ) {
        my @p = $v->parts;
        push @parts, \@p;
        my $w = _widths( \@p );
        if ($widths) {
            for ( 0 .. $#$w ) {
                my ( $l1, $l2 ) = ( $w->[$_], $widths->[$_] );
                $widths->[$_] = $l1 if $l1 > $l2;
            }
        }
        else {
            $widths = $w;
        }
    }
    return [] unless @parts;
    my $format = sprintf "%%%dd) %%%ds %%-%ds %%-%ds %%-%ds\n",
      length scalar(@parts),
      @$widths;
    for my $i ( 0 .. $#parts ) {
        $parts[$i] = sprintf $format, $i + 1, @{ $parts[$i] };
    }
    return \@parts;
}

=method add_overlaps

Adds appropriate vacation times to a set of events.

=cut

sub add_overlaps {
    my ( $self, $events ) = @_;
    my ( %day_map, @overlaps );
    for my $e (@$events) {
        for my $v ( @{ $self->{data} } ) {
            my $o = $v->overlap($e);
            if ($o) {
                my $s = $o->start . ' ' . $o->end;
                unless ( $day_map{$s} ) {
                    $day_map{$s} = 1;
                    push @overlaps, $o;
                }
            }
        }
    }
    return $events unless @overlaps;
    push @overlaps, @$events;
    return [ sort { $a->cmp($b) } @overlaps ];
}

# collect the widths of a list of strings
sub _widths {
    my ($ar) = @_;
    my @w;
    push @w, length $_ for @$ar;
    return \@w;
}

1;
