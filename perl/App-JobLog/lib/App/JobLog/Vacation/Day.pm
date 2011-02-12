package App::JobLog::Vacation::Day;

# ABSTRACT: still working on this

=pod

=head1 NAME

App::JobLog::Vacation::Day - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = App::JobLog::Vacation::Day->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

=pod

=head2 new

  my $object = App::JobLog::Vacation::Day->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<App::JobLog::Vacation::Day> object.

So no big surprises there...

Returns a new B<App::JobLog::Vacation::Day> or dies on error.

=cut

sub new {
	my $class = shift;
	my $self  = bless { @_ }, $class;
	return $self;
}

=pod

=head2 dummy

This method does something... apparently.

=cut

sub dummy {
	my $self = shift;

	# Do something here

	return 1;
}

1;

=pod

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2010 Anonymous.

=cut
