package App::JobLog::Log::Line;

# ABSTRACT: encapsulates one line of log text

=head1 DESCRIPTION

B<App::JobLog::Log::Line> encapsulates a line of text from the log -- the semantics of such
a line and the code required to construct, parse, or serialize it.

=cut

use Modern::Perl;
use Class::Autouse qw{DateTime};
use autouse 'App::JobLog::Time' => qw(now tz);

# represents a single non-comment line in the log
# not using Moose to keep CLI snappy

# to_string method for convenience
use overload '""' => \&to_string;
use overload 'bool' => sub { 1 };

# some global variables for use in BNF regex
our ( $date, @tags, @description, $is_beginning );

# log line parser
our $re = qr{
    ^ (?&ts) : (?&non_ts) $
    (?(DEFINE)
     (?<ts> (\d{4}+\s++\d++\s++\d++\s++\d++\s++\d++\s++\d++) (?{$date = $^N}) )
     (?<non_ts> (?&done) (?{$is_beginning = undef})| (?&event) (?{$is_beginning = 1}))
     (?<done> DONE)
     (?<event> (?&tags) : (?&descriptions))
     (?<tags> (?:(?&tag)(\s++(?&tag))*+)?)
     (?<tag> ((?:[^\s:\\]|(?&escaped))++) (?{push @tags, $^N}))
     (?<escaped> \\.)
     (?<descriptions> (?: (?&description) (?: ; \s*+ (?&description) )*+ )? )
     (?<description> ((?:[^;\\]|(?&escaped))++) (?{push @description, $^N}))
    )
}xi;

=method new

For composing a log line out of a hash of attributes.

=cut

sub new {
    my ( $class, @args ) = @_;
    $class = ref $class || $class;
    my %opts = @args;

    # validate %opts
    my $self = bless {}, $class;
    if ( exists $opts{comment} ) {
        $self->{comment} = $opts{comment};
        delete $opts{comment};
        die 'inconsistent arguments: ' . join( ', ', @args ) if keys %opts;
    }
    elsif ( exists $opts{done} ) {
        my $time = $opts{time};
        die "invalid value for time: $time"
          if $time && ref $time ne 'DateTime';
        $self->{time} = $time || now;
        $self->{done} = 1;
        delete $opts{done};
        delete $opts{time};
        die 'inconsistent arguments: ' . join( ', ', @args ) if keys %opts;
    }
    elsif ( exists $opts{time} ) {
        my $time = $opts{time};
        die "invalid value for time: $time"
          if $time && ref $time ne 'DateTime';
        $self->{time} = $time;
        my $tags = $opts{tags};
        die 'invalid value for tags: ' . $tags
          if defined $tags && ref $tags ne 'ARRAY';
        unless ($tags) {
            $tags = [];
            $self->{tags_unspecified} = 1;
        }
        $self->{tags} = $tags;
        my $description = $opts{description};
        if ( my $type = ref $description ) {
            die 'invalid type for description: ' . $type
              unless $type eq 'ARRAY';
            $self->{description} = $description;
        }
        elsif ( defined $description ) {
            $description = [$description];
        }
        else {
            $description = [];
        }
        $self->{description} = $description;
        delete @opts{qw(time tags description)};
        die 'inconsistent arguments: ' . join( ', ', @args ) if keys %opts;
    }
    elsif ( exists $opts{text} ) {
        die 'text lines in log must be blank' if $opts{text} =~ /\S/;
        $self->{text} = $opts{text} . '';
        delete $opts{text};
        die 'inconsistent arguments: ' . join( ', ', @args ) if keys %opts;
    }
    return $self;
}

=method parse

For parsing a line in an existing log. Expects string to parse as an argument.

=cut

sub parse {
    my ( $class, $text ) = @_;
    my $obj = bless { text => $text }, $class;
    if ( $text =~ /^\s*(?:#\s*+(.*?)\s*)?$/ ) {
        if ( defined $1 ) {
            $obj->{comment} = $1;
            delete $obj->{text};
        }
        return $obj;
    }
    local ( $date, @tags, @description, $is_beginning );
    if ( $text =~ $re ) {

        # must use to_string to obtain text
        delete $obj->{text};
        my @time = split /\s++/, $date;
        $date = DateTime->new(
            year      => $time[0],
            month     => $time[1],
            day       => $time[2],
            hour      => $time[3],
            minute    => $time[4],
            second    => $time[5],
            time_zone => tz,
        );
        $obj->{time} = $date;
        if ($is_beginning) {
            my %tags = map { $_ => 1 } @tags;
            $obj->{tags} =
              [ map { ( my $v = $_ ) =~ s/\\(.)/$1/g; $v } sort keys %tags ];
            $obj->{description} = [
                map {
                    ( my $v = $_ ) =~ s/\\(.)/$1/g;
                    $v =~ s/^\s++|\s++$//g;
                    $v =~ s/\s++/ /g;
                    $v
                  } @description
            ];
        }
        else {
            $obj->{done} = 1;
        }
        return $obj;
    }
    else {
        $obj->{malformed} = 1;
    }
    return $obj;
}

=method clone

Produces an object semantically identical to that on which it was invoked but
stored without shared references so changes to the latter will not effect the former.

=cut

sub clone {
    my ($self) = @_;
    my $clone = bless {}, ref $self;
    if ( $self->is_malformed ) {
        $clone->{malformed} = 1;
        $clone->text = $self->text;
    }
    elsif ( $self->is_event ) {
        $clone->time = $self->time->clone;
        if ( $self->is_beginning ) {
            $clone->tags        = [ @{ $self->tags } ];
            $clone->description = [ @{ $self->description } ];
        }
    }
    else {
        $clone->comment = $self->comment if $self->is_comment;
        $clone->text    = $self->text    if exists $self->{text};
    }
    return $clone;
}

=method to_string

Serializes object to the string that would represent it in a log.

=cut

sub to_string {
    my ($self) = @_;
    return $self->{text} if exists $self->{text};
    if ( $self->is_event ) {
        my $text = $self->time_stamp;
        $text .= ':';
        if ( $self->is_beginning ) {
            $self->tags ||= [];
            my %tags = map { $_ => 1 } @{ $self->tags };
            $text .= join ' ', map { s/([:\\\s])/\\$1/g; $_ } sort keys %tags;
            $text .= ':';
            $self->description ||= [];
            $text .= join ';',
              map { ( my $d = $_ ) =~ s/([;\\])/\\$1/g; $d }
              @{ $self->description };
        }
        else {
            $text .= 'DONE';
        }
        return $text;
    }
    elsif ( $self->is_comment ) {
        return '# ' . $self->comment;
    }
}

=method time_stamp

Represents optional L<DateTime> object in the format used in the log. If no
argument is provided, the timestamp of the line itself is returned.

=cut

sub time_stamp {
    my ( $self, $time ) = @_;
    $time ||= $self->time;
    return sprintf '%d %2s %2s %2s %2s %2s', $time->year, $time->month,
      $time->day,    $time->hour,
      $time->minute, $time->second;
}

# a bunch of attributes, here for convenience

=method text

Accessor to text attribute of line, if any. Should only be defined for well formed
log lines. Is lvalue.

=cut

sub text : lvalue {
    $_[0]->{text};
}

=method tags

Accessor to array reference containing tags, if any. Is lvalue.

=cut

sub tags : lvalue {
    $_[0]->{tags};
}

=method comment

Accessor to comment value, if any. Should only be defined for comment lines. Is lvalue.

=cut

sub comment : lvalue {
    $_[0]->{comment};
}

=method time

Accessor to time value, if any. Should only be defined for event lines. Lvalue.

=cut

sub time : lvalue {
    $_[0]->{time};
}

=method description

Accessor to reference to description list. Should only be defined for lines describing the
beginning of an event. Lvalue.

=cut

sub description : lvalue {
    $_[0]->{description};
}

# a bunch of tests

=method

Whether lines is malformed.

=cut

sub is_malformed     { exists $_[0]->{malformed} }

=method is_beginning

Whether line describes the beginning of an event.

=cut

sub is_beginning     { exists $_[0]->{tags} }

=method is_end

Whether line only defines the end of an event.

=cut

sub is_end           { $_[0]->{done} }

=method is_event

Whether line defines the beginning or end of an event.

=cut

sub is_event         { $_[0]->{time} }

=method is_comment

Whether line represents a comment in the log.

=cut

sub is_comment       { exists $_[0]->{comment} }

=method tags_unspecified

Whether object was constructed from a hash of values that contained no C<tags> key.

=cut

sub tags_unspecified { $_[0]->{tags_unspecified} }

=method is_blank

Whether object represents a blank line in the log.

=cut

sub is_blank {
    !( $_[0]->is_malformed || $_[0]->is_comment || $_[0]->is_event );
}

# some useful methods

=method comment_out

Convert this into a comment line.

=cut

sub comment_out {
    my ($self) = @_;
    my $text = $self->to_string;
    delete $self->{$_} for keys %$self;
    $self->{comment} = $text;
    return $self;
}

=method all_tags

Expects list of tags. Returns whether all tags in list are present in object.

=cut

sub all_tags {
    my ( $self, @tags ) = @_;
    return unless $self->tags;
    my %tags = map { $_ => 1 } @{ $self->{tags} };
    for my $tag (@tags) {
        return unless $tags{$tag};
    }
    return 1;
}

=method exists_tag

Expects list of tags. Returns whether any member of list is among tags of object.

=cut

sub exists_tag {
    my ( $self, @tags ) = @_;
    return unless $self->tags;
    my %tags = map { $_ => 1 } @{ $self->{tags} };
    for my $tag (@tags) {
        return 1 if $tags{$tag};
    }
    return;
}

1;
