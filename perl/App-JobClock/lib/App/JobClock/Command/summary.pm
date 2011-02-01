package App::JobClock::Command::summary;
use App::JobClock -command;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(summary) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' <date or date range>' }

sub abstract { 'list tasks with certain properties in a particular time range' }

sub options {
    return (
        [ "skip-refs|R", "skip reference checks during init", ],
        [ "values|v=s@", "starting values", { default => [ 0, 1, 3 ] } ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    # we need at least one argument beyond the options; die with that message
    # and the complete "usage" text describing switches, etc
    $self->usage_error("too few arguments") unless @$args;
}

1;
