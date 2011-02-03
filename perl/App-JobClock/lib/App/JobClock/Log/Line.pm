package App::JobClock::Log::Line;
use Class::Autouse qw{DateTime};
use Modern::Perl;

# represents a single non-comment line in the log
# not using Moose to keep CLI snappy

# to_string method for convenience
use overload '""' => sub { $_[0]->{text} };

# some global variables for use in BNF regex
our ( $date, @tags, $description, $is_beginning );

# log line parser
my $re = qr{
    ^ (?&ts) : (?&non_ts) $
    (?(DEFINE)
     (?<ts> \d{4}+\s\d++\s\d++\s\d++\s\d++\s\d++ (?{$date = $^N}) )
     (?<non_ts> (?&done) (?{$is_beginning = undef})| (?&event) (?{$is_beginning = 1}))
     (?<done> DONE)
     (?<event> (?&tags) : (?&description))
     (?<tags> (?:(?&tag)(\s++(?&tag))*+)?)
     (?<tag> ([^\s:\\]|(?&escaped))++ (?{push @tags, $^N}))
     (?<escaped> \\.)
     (?<description> .+ (?{$description = $^N}))
    )
}xi;

# for composing a log line out of a hash of attributes
sub new {
    my ( undef, %opts ) = @_;
    # TODO validate %opts
    my $self = bless \%opts;
    if ( $self->is_event ) {
        my $time = $self->time;
        my $text = join ' ', $time->year, $time->month, $time->day, $time->hour,
          $time->minute, $time->second;
        $text .= ':';
        $self->tags ||= [];
        $text .= join ' ', map { _escape($_) } @{ $self->tags };
        $text .= ':';
        $self->description ||= '';
        $text .= $self->description;
        $self->text = $text;
    }
    else if ( $self->is_comment ) {
        $self->text = '# ' . $self->comment;
    }
    return $self;
}

# escape tag text
sub _escape {
    $_[0] =~ s/([:\\\s])/\\$1/g;
    $_[0];
}

# for parsing a line in an existing log
sub parse {
    my ( undef, $text ) = @_;
    my $obj = bless { text => $text };
    if ( $text =~ /^\s*(?:#\s*+(.*?)\s*)$/ ) {
        $obj->{comment} = $1 if defined $1;
        return $obj;
    }
    $is_beginning = 1;
    @tags         = ();
    if ( $text =~ $re ) {
        my @time = split / /, $date;
        $date = DateTime->new(
            year   => $time[0],
            month  => $time[1],
            day    => $time[2],
            hour   => $time[3],
            minute => $time[4],
            second => $time[5],
        );
        $obj->{time} = $date;
        if ($is_beginning) {
            $obj->{tags}        = [@tags];
            $obj->{description} = $description;
        }
        return $obj;
    }
    $obj->{malformed} = 1;
    return $obj;
}

# a bunch of attributes, here for convenience

sub text : lvalue {
    $_[0]->{text};
}

sub tags : lvalue {
    $_[0]->{tags};
}

sub comment : lvalue {
    $_[0]->{comment};
}

sub time : lvalue {
    $_[0]->{time};
}

sub description : lvalue {
    $_[0]->{description};
}

# a bunch of tests

sub is_malformed { exists $_[0]->{malformed} }
sub is_beginning { exists $_[0]->{tags} }
sub is_end       { $_[0]->is_event && !$_[0]->is_beginning }
sub is_event     { exists $_[0]->{time} }
sub is_comment   { exists $_[0]->{comment} }

1;

# TODO edit the boilerplate below

__END__

=pod

=head1 NAME

App::JobClock::Log::Line - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = App::JobClock::Log::Line->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=head2 new

  my $object = App::JobClock::Log::Line->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<App::JobClock::Log::Line> object.

So no big surprises there...

Returns a new B<App::JobClock::Log::Line> or dies on error.

=head2 dummy

This method does something... apparently.

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2010 Anonymous.

=cut
