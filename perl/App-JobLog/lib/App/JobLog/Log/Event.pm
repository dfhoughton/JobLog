package App::JobLog::Log::Event;

# ABSTRACT: basically adds an end time to App::JobLog::Log::Line events

use Modern::Perl;
use Class::Autouse qw{DateTime};

sub new {
    my ( undef, $logline ) = @_;
    my $self = bless { log => $logline };
    return $self;
}

# the portion of an event falling within given interval
sub overlap {
    my ( $self, $start, $end ) = @_;

    # if this falls entirely within interval, return this
    my $c1 = DateTime->compare( $start, $self->start ) || 0;
    my $c2 = DateTime->compare( $end,   $self->end ) || 0;
    if ( $c1 <= 0 && $c2 >= 0 ) {
        return $self;
    }
    my $s = $c1 < 0 ? $self->start : $start;
    my $e = $c2 < 0 ? $end         : $self->end;
    my $clone = __PACKAGE__->new( $self->data->clone );
    $clone->start = $s;
    $clone->end   = $e;
    return $clone;
}

sub data {
    $_[0]->{log};
}

sub start : lvalue {
    $_[0]->data->time;
}

sub end : lvalue {
    $_[0]->{end};
}

sub tags : lvalue {
    $_[0]->data->{tags};
}

sub exists_tag {
    my ( $self, @tags ) = @_;
    $self->data->exists_tag(@tags);
}

sub all_tags {
    my ( $self, @tags ) = @_;
    $self->data->all_tags(@tags);
}

# for sorting
sub cmp {
    my ( $self, $other ) = @_;
    my $comparison = DateTime->compare( $self->start, $other->start );
    unless ($comparison) {
        if ( $self->is_closed ) {
            if ( $other->is_closed ) {
                return DateTime->compare( $self->end, $other->end );
            }
            else {
                return 1;
            }
        }
        elsif ( $other->is_closed ) {
            return -1;
        }
        else {
            return 0;
        }
    }
    return $comparison;
}

sub is_closed { exists $_[0]->{end} }

sub is_open { !$_[0]->is_closed }

1;

__END__

=pod

=head1 NAME

App::JobLog::Log::Event - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = App::JobLog::Log::Event->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=head2 new

  my $object = App::JobLog::Log::Event->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<App::JobLog::Log::Event> object.

So no big surprises there...

Returns a new B<App::JobLog::Log::Event> or dies on error.

=head2 dummy

This method does something... apparently.

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2010 Anonymous.

=cut
