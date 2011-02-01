package App::JobClock::Command;
use App::Cmd::Setup -command;
use Modern::Perl;

sub opt_spec {
    my ( $class, $app ) = @_;
    my @overview = $class->overview;
    push @overview, [] if @overview;
    my @options = $class->options($app);
    push @overview, @options, [] if @options;
    return ( @overview, [ 'help' => "this usage screen" ] );
}

# override this in subclasses for more detailed descriptions or to eliminate them altogether
sub overview { [ (shift)->abstract ] }

sub validate_args {
    my ( $self, $opt, $args ) = @_;
    die $self->_usage_text if $opt->{help};
    $self->validate( $opt, $args );
}

# obtains command name
sub name {
    ( my $command = shift ) =~ s/.*:://;
    return $command;
}

# by default a command has no options other than --help
sub options { }

# by default a command does no argument validation
sub validate { }

1;
