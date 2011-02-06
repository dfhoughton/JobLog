package;

# ABSTRACT: basically adds an end time to App::JobLog::Log::Line events

use Modern::Perl;
use Class::Autouse qw{Date::Time};


sub new {
    my ( undef, $logline ) = @_;
    my $self = bless { log => $logline };
    return $self;
}

sub data : lvalue {
    $_[0]->{log};
}

sub start { $_[0]->time }

sub end : lvalue {
    $_[0]->{end};
}

# for sorting
sub cmp {
    my ($self, $other) = @_;
    my $comparison = Date::Time->compare($self->start, $other->start);
    unless ($comparison) {
        if ($self->is_closed) {
            if ($other->is_closed) {
                return Date::Time->compare($self->end, $other->end);
            } else {
                return 1;
            }
        } else if ($other->is_closed) {
            return -1;
        } else {
            return 0;
        }
    }
    return $comparison;
}

sub is_closed { exists $_[0]->{end} }

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
