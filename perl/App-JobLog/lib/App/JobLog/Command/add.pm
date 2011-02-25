package App::JobLog::Command::add;

# ABSTRACT: log an event

use App::JobLog -command;
use Modern::Perl;
use autouse 'Getopt::Long::Descriptive' => qw(prog_name);
use autouse 'App::JobLog::Time'         => qw(now);
use Class::Autouse qw(App::JobLog::Log);

sub execute {
    my ( $self, $opt, $args ) = @_;
    my $tags = $opt->tag;
    unless ($tags) {
        $tags = [] if $opt->clear_tags;
    }
    App::JobLog::Log->new->append_event(
        $tags ? ( tags => $tags ) : (),
        description => [ join ' ', @$args ],
        time        => now
    );
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' <description of event>' }

sub abstract { 'log an event' }

sub full_description {
    <<END;
Log an event. E.g.,

  @{[prog_name($0)]} @{[__PACKAGE__->name]} munging the widget

All arguments that are not parameter values are concatenated as a description
of the event. Logging an event simultaneously marks the end of the previous
event. Events may be tagged to mark such things as client, grant, or 
project.
END
}

sub options {
    return (
        [
            'tag|t=s@',
'tag the event; multiple tags are acceptable; e.g., -t foo -t bar -t quux',
        ],
        [
            'clear-tags|T',
            'inherit no tags from preceding event; '
              . 'this is equivalent to -t ""; '
              . 'this option has no effect if any tag is specified',
        ],

    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('no description provided') unless @$args;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
