package App::JobLog::Vacation;

# ABSTRACT: controller for the vacation model

=head1 DESCRIPTION

Code to manage vacation times.

=cut

{

    package Period;

    use base 'App::JobLog::Log::Event';
    use DateTime;
    use App::JobLog::Log::Line;
    use App::JobLog::Time qw(tz);
    use Carp qw(carp);

    use overload '""' => \&to_string;

    sub flex : lvalue {
        $_[0]->{flex};
    }

    # some global variables for use in BNF regex
    our ( @dates, $is_flex, @tags, $description );

    # log line parser
    my $re = qr{
    ^ (?&ts) : (?&non_ts) $
    (?(DEFINE)
     (?<ts> (?&date) : (?&date) )
     (?<date> (\d{4}+\s++\d++\s++\d++\s++\d++\s++\d++\s++\d++) (?{push @dates, $^N}) )
     (?<non_ts> (?&flex) : (?&tags) : (?&description))
     (?<flex> ([01]) (?{$is_flex = $^N}))
     (?<tags> (?:(?&tag)(\s++(?&tag))*+)?)
     (?<tag> ((?:[^\s:\\]|(?&escaped))++) (?{push @tags, $^N}))
     (?<escaped> \\.)
     (?<description> (.++) (?{$description = $^N}))
    )
}xi;

    # for parsing a line in an existing log
    sub parse {
        my ( undef, $text ) = @_;
        local ( @dates, $is_flex, @tags, $description );
        if ( $text =~ $re ) {
            my $start = _parse_time( $dates[0] );
            $obj->{time} = $start;
            my %tags = map { $_ => 1 } @tags;
            $obj->{tags} = [ map { s/\\(.)/$1/g; $_ } sort keys %tags ];
            $obj->{description} = [ map { s/\\(.)/$1/g; $_ } ($description) ];
            $obj       = __PACKAGE__->new($obj);
            $obj->flex = $is_flex;
            $obj->end  = _parse_time( $dates[1] );
            return $obj;
        }
        else {
            carp "malformed line in vacation file: '$text'";
        }
        return undef;
    }

    sub _parse_time {
        my @time = split /\s++/, $_[0];
        $date = DateTime->new(
            year      => $time[0],
            month     => $time[1],
            day       => $time[2],
            hour      => $time[3],
            minute    => $time[4],
            second    => $time[5],
            time_zone => tz,
        );
        return $date;
    }

    sub to_string {
        my ($self) = @_;
        my $text = $self->data->time_stamp( $self->start );
        $text .= ':';
        $text .= $self->data->time_stamp( $self->end );
        $text .= ':';
        $text .= $self->flex;
        $text .= ':';
        $self->tags ||= [];
        my %tags = map { $_ => 1 } @{ $self->tags };
        $text .= join ' ', map { s/([:\\\s])/\\$1/g; $_ } sort keys %tags;
        $text .= ':';
        $self->description ||= [];
        $text .= join ';',
          map { ( my $d = $_ ) =~ s/([;\\])/\\$1/g; $d }
          @{ $self->description };
    }
    
    sub display { "foo" }
}

use Modern::Perl;
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
    my $self = bless { changed => 0 };
    if ( -e vacation ) {
        my $fh = FileHandle->new(vacation);
        my @data;
        while ( my $line = <$fh> ) {
            chomp $line;
            my $v = Period->parse($line);
            push @data, $v;
        }
        $self->{data} = [ sort { $a->cmp($b) } @data ];
    }
    return bless { changed => 0 };
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
    my $end  = $opts{end};
    my $flex = $opts{flex};
    delete @opts{qw(end flex)};
    my $ll = App::JobLog::Log::Line->new(%opts);
    my $v  = Period->new($ll);
    $v->end  = $end;
    $v->flex = $flex;
    push @{ $self->{data} }, $v;
    $self->{data} = [ sort { $a->cmp($b) } @{ $self->{data} } ];
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
    splice @$data, $index, 1;
    $self->{changed} = 1;
}

1;
