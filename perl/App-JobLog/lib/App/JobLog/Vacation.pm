package App::JobLog::Vacation;

# ABSTRACT: controller for the vacation model

use Modern::Perl;
use App::JobLog::Config;
use App::JobLog::Log::Event;
use App::JobLog::Log::Line;
use autouse 'Data::Dump' => qw(dump);
use Class::Autouse qw{FileHandle};

sub new {
    if ( -e App::JobLog::Config->vacation ) {
        return do App::JobLog::Config->vacation;
    }
    return bless { changed => 0 };
}

# save any changes
sub close {
    my ($self) = @_;
    if ( $self->{changed} ) {
        if ( @{ $self->{data} } ) {

            # something to save
            $self->{changed} = 0;
            my $fh = FileHandle->new( App::JobLog::Config->vacation, 'w' );
            print $fh dump($self);
            $fh->close;
        }
        else {
            unlink( App::JobLog::Config->vacation )
              if -e App::JobLog::Config->vacation;
        }
    }
}

sub add {
    my ( $self, %opts ) = @_;
    my $end = $opts{end};
    delete $opts{end};
    my $ll    = App::JobLog::Log::Line->new(%opts);
    my $event = App::JobLog::Log::Event->new($ll);
    $event->end = $end;
    push @{ $self->{data} }, $event;
    $self->{data} = [ sort { $a->cmp($b) } @{ $self->{data} } ];
    $self->{changed} = 1;
}

sub remove {
    my ( $self, $index ) = @_;
    die "vacation date index must be non-negative" if $index < 0;
    my $data = $self->{data};
    die "unknown vacation date" unless $data && @$data > $index;
    splice @$data, $index, 1;
    $self->{changed} = 1;
}

1;

__END__

=pod

=head1 NAME

App::JobLog::Vacation - My author was too lazy to write an abstract

=head1 SYNOPSIS

  my $object = App::JobLog::Vacation->new(
      foo  => 'bar',
      flag => 1,
  );
  
  $object->dummy;

=head1 DESCRIPTION

The author was too lazy to write a description.

=head1 METHODS

=head2 new

  my $object = App::JobLog::Vacation->new(
      foo => 'bar',
  );

The C<new> constructor lets you create a new B<App::JobLog::Vacation> object.

So no big surprises there...

Returns a new B<App::JobLog::Vacation> or dies on error.

=head2 dummy

This method does something... apparently.

=head1 SUPPORT

No support is available

=head1 AUTHOR

Copyright 2010 Anonymous.

=cut
