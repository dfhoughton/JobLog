package App::JobLog::Command::add;

# ABSTRACT: log an event

use App::JobLog -command;
use Modern::Perl;
use autouse 'Getopt::Long::Descriptive' => qw(prog_name);

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(add) Everything has been initialized.  (Not really.)\n";
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
