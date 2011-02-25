package App::JobLog::Command::vacation;

# ABSTRACT: controller for vacation dates

use Modern::Perl;
use App::JobLog -command;
use autouse 'App::JobLog::TimeGrammar' => qw(parse);
use Class::Autouse qw(App::JobLog::Vacation);

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $vacation = App::JobLog::Vacation->new;
    if ( $opt->list ) {
        _show($vacation);
    }
    else {
        given ( $opt->modification ) {
            when ('add') {
                my $time = join ' ', @$args;
                eval {
                    my ( $s, $e ) = parse($time);
                    $vacation->add(
                        description => $opt->description,
                        time        => $s,
                        end         => $e,
                        flex        => $opt->flex || 0,
                        tags        => $opt->tags
                    );
                };
                $self->usage_error($@) if $@;
            }
            when ('remove') {
                eval { $vacation->remove( $opt->remove ); };
                $self->usage_error($@) if $@;
            }
        }
        _show($vacation);
        $vacation->close;
    }
}

sub _show {
    my ($vacation) = @_;
    my @periods = $vacation->periods;
    my $fmt = sprintf "%%%ds) %%s\n", scalar @periods;
    for my $i (1 .. @periods) {
        printf $fmt, $i, $periods[$i - 1]->display;
    }
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' %o' }

sub abstract { 'list or define days off' }

sub options {
    return (
        [ 'list|l', 'show all vacation times recorded', ],
        [
            'flex|f',
'add sufficient vacation time to complete workday; this is recorded with the "flex" tag'
        ],
        [ 'description|d=s', 'a description of the vacation period' ],
        [ 'tag|t=s@',        'tag vacation time; e.g., -a yesterday -t float' ],
        [
            'modification' => 'hidden' => {
                one_of => [
                    [ 'add|a=s', 'add date or range; e.g., -a "May 17, 1951"' ],
                    [
                        'delete|d=i',
'delete date with given index in list (see --list); e.g., -d 1'
                    ],
                ]
            }
        ]
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('either list or modify')
      if ( $opt->list && $opt->modification )
      || !( $opt->list || $opt->modification );
    $self->usage_error('--flex requires that you add a date')
      if $opt->flex && !( ( $opt->modification || '' ) eq 'add' );
    $self->usage_error('--tag requires that you add a date')
      if $opt->tag && !( ( $opt->modification || '' ) eq 'add' );
    $self->usage_error('vacation periods require descriptions')
      if ( ( $opt->modification || '' ) eq 'add' )
      && !defined $opt->description;
    $self->usage_error('no time period provided')
      if ( ( $opt->modification || '' ) eq 'add' ) && !@$args;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
