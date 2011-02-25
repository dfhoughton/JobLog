package App::JobLog::Command::modify;

# ABSTRACT: modify last logged event

use App::JobLog -command;
use Modern::Perl;
use Class::Autouse qw(App::JobLog::Log);

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $log = App::JobLog::Log->new;
    my ( $e, $i ) = $log->last_event;
    my $ll = $e->data;
    if ( $opt->clear_tags ) {
        $ll->tags = [];
    }
    elsif ( $opt->untag ) {
        my %tags = map { $_ => 1 } @{ $ll->tags };
        delete $tags{$_} for @{ $opt->untag };
        $ll->tags = [ sort keys %tags ];
    }
    if ( $opt->tag ) {
        my %tags = map { $_ => 1 } @{ $ll->tags };
        $tags{$_} = 1 for @{ $opt->tag };
        $ll->tags = [ sort keys %tags ];
    }
    my $description = join ' ', @$args;
    given ( $opt->desc || '' ) {
        when ('replace_description') {
            $ll->description = [$description];
        }
        when ('add_description') {
            push @{ $ll->description }, $description;
        }
    }
    $log->replace( $i, $ll );
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o [<description>]' }

sub abstract { 'add details to last event' }

sub options {
    return (
        [
            desc => hidden => {
                one_of => [
                    [ "add-description|a" => "add some descriptive text" ],
                    [
                        "replace-description|r" => "replace current description"
                    ],
                ]
            }
        ],
        [ "tag|t=s@",     "add tag; e.g., -t foo -t bar" ],
        [ "untag|u=s@",   "remove tag; e.g., -u foo -u bar" ],
        [ "clear-tags|c", "remove all tags" ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    my $has_modification = grep { $_ } @{$opt}{qw(desc tag untag clear_tags)};
    $self->usage_error('no modification specified') unless $has_modification;

    if ( $opt->desc ) {
        $self->usage_error('no description provided') unless @$args;
    }
}

1;
