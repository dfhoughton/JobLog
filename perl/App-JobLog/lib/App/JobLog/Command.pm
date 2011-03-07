package App::JobLog::Command;

# ABSTRACT: common functionality of App::JobLog commands

use App::Cmd::Setup -command;
use Modern::Perl;
use App::JobLog::Config qw(columns);

sub opt_spec {
    my ( $class, $app ) = @_;

    return ( $class->options($app), [ 'help' => "this usage screen" ] );
}

# makes sure everything has some sort of description
sub description {
    my ($self) = @_;

    # abstract provides default text
    my $desc = $self->full_description;
    unless ($desc) {
        ( $desc = $self->abstract ) =~ s/^\s++|\s++$//g;

        # ensure initial capitalization
        $desc =~ s/^(\p{Ll})/uc $1/e;

        # add sentence-terminal punctuation as necessary
        $desc =~ s/(\w)$/$1./;
    }

    # make sure things are wrapped nicely
    require Text::WrapI18N;
    $Text::WrapI18N::columns = columns;
    $desc = Text::WrapI18N::wrap( '', '', $desc );

    # space between description and options text
    $desc .= "\n";
    return $desc;
}

# override to make full description
sub full_description { }

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

__END__

=pod

=head1 DESCRIPTION

B<App::JobLog::Command> adds a small amount of specialization and functionality to L<App::Cmd> commands. In
particular it adds a C<--help> option to every command and ensures that they all have some minimal longer
form description that can be obtained with the C<help> command.

=cut
