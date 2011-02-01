package App::JobClock::Command::modify;
use App::JobClock -command;
use Modern::Perl;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(modify) Everything has been initialized.  (Not really.)\n";
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'add details to current task' }

sub options {
    return (
        [
            desc => hidden => {
                one_of => [
                    [ "add-description|a=s" => "add some descriptive text" ],
                    [
                        "replace-description|r=s" =>
                          "replace current description"
                    ],
                ]
            }
        ],
        [ "tag|t=s@",   "add tag; e.g., -t foo -t bar" ],
        [ "untag|u=s@", "remove tag; e.g., -u foo -u bar" ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    my $has_modification = grep { $_ } @{$opt}{qw(desc tag untag)};
    $self->usage_error('no modification specified') unless $has_modification;
}

1;
