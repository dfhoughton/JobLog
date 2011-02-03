package App::JobClock::Log;


use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';


sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}


sub dummy {
	my $self = shift;

	# Do something here

	return 1;
}

1;

__END__

=pod

=head1 NAME

App::JobClock::Log - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = App::JobClock::Log->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=head2 new

  my $object = App::JobClock::Log->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<App::JobClock::Log> object.

So no big surprises there...

Returns a new B<App::JobClock::Log> or dies on error.

=head2 dummy

This method does something... apparently.

=head1 SUPPORT

No support is available

=head1 AUTHOR

David Houghton <dfhoughton@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by David Houghton.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
