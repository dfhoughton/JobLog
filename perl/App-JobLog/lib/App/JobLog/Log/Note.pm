package App::JobLog::Log::Note;

# ABSTRACT: timestamped annotation in log

=head1 DESCRIPTION

B<App::JobLog::Log::Time> fill this out.

=cut

use Modern::Perl;
use Class::Autouse qw{DateTime};
use autouse 'App::JobLog::Time' => qw(now);
use autouse 'Carp'              => qw(carp);

# for debugging
use overload '""' => sub {
   $_[0]->data->to_string;
};
use overload 'bool' => sub { 1 };

=method new

Basic constructor. Expects single L<App::JobLog::Log::Line> argument. Can be called on
instance or class.

=cut

sub new {
   my ( $class, $logline ) = @_;
   $class = ref $class || $class;
   my $self = bless { log => $logline }, $class;
   return $self;
}

=method clone

Create a duplicate of this event.

=cut

sub clone {
   my ($self) = @_;
   my $clone = $self->new( $self->data->clone );
   return $clone;
}

=method data

Returns L<App::JobLog::Log::Line> object on which this event is based.

=cut

sub data {
   $_[0]->{log};
}

=method start

Start of event. Is lvalue method.

=cut

sub start : lvalue {
   $_[0]->data->time;
}

=method tags

Tags of event (array reference). Is lvalue method.

=cut

sub tags : lvalue {
   $_[0]->data->{tags};
}

=method tagged

Whether there are any tags.

=cut

sub tagged { !!@{ $_[0]->tags } }

=method tag_list

Returns tags as list rather than reference.

=cut

sub tag_list { @{ $_[0]->tags } }

=method describe

Returns the log line's description.

=cut

sub describe {
   my ($self) = @_;
   join '; ', @{ $self->data->description };
}

=method exists_tag

Expects a list of tags. Returns true if event contains any of them.

=cut

sub exists_tag {
   my ( $self, @tags ) = @_;
   $self->data->exists_tag(@tags);
}

=method all_tags

Expects a list of tags. Returns whether event contains all of them.

=cut

sub all_tags {
   my ( $self, @tags ) = @_;
   $self->data->all_tags(@tags);
}

=method cmp

Used to sort events. E.g.,

 my @sorted_events = sort { $a->cmp($b) } @unsorted;

=cut

sub cmp {
   my ( $self, $other ) = @_;
   carp 'argument must also be time' unless $other->isa(__PACKAGE__);

   # defer to subclass sort order if other is a subclass and self isn't
   return -$other->cmp($self)
     if ref $self eq __PACKAGE__ && ref $other ne __PACKAGE__;

   return DateTime->compare( $self->start, $other->start );
}

=method split_days

Returns note itself. This method is overridden by the event object and used in
event summarization.

=cut

sub split_days {
   return $_[0];
}

=method intersects

Whether this note overlaps the given period.

=cut

sub intersects {
   my ( $self, $other ) = @_;
   if ( $other->can('end') ) {
      return $self->start >= $other->start && $self->start < $other->end;
   }
   return $self->start == $other->start;
}

=method is_open

Returns false: notes have no duration so they cannot be open.

=cut

sub is_open { 0 }

1;
