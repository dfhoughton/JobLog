package App::JobLog::Command::vacation;

# ABSTRACT: controller for vacation dates

use Modern::Perl;
use App::JobLog -command;
use autouse 'App::JobLog::TimeGrammar' => qw(parse);
use Class::Autouse qw(App::JobLog::Vacation);

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $vacation = App::JobLog::Vacation->new;
    if ( $opt->modification ) {
        given ( $opt->modification ) {
            when ('add') {
                my $time = join ' ', $opt->add;
                eval {
                    my ( $s, $e ) = parse($time);
                    $vacation->add(
                        description => join( ' ', @$args ),
                        time        => $s,
                        end         => $e,
                        annual      => $opt->annual,
                        monthly     => $opt->monthly,
                        flex => $opt->flex || 0,
                        tags => $opt->tag
                    );
                };
                $self->usage_error($@) if $@;
            }
            when ('remove') {
                eval { $vacation->remove( $opt->remove ); };
                $self->usage_error($@) if $@;
            }
        }
    }
    _show($vacation);
    $vacation->close;
}

sub _show {
    my ($vacation) = @_;
    my $lines = $vacation->show;
    if (@$lines) {
        print $_ for @$lines;
    }
    else {
        say 'no vacation times recorded';
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
        [ 'tag|t=s@', 'tag vacation time; e.g., -a yesterday -t float' ],
        [
            'repeat' => 'hidden' => {
                one_of => [
                    [ 'annual',  'vacation period repeats annually' ],
                    [ 'monthly', 'vacation period repeats monthly' ],
                ]
            }
        ],
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

    my $mod = $opt->modification || '';
    my $is_add = $mod eq 'add';
    $self->usage_error('either list or modify')
      if ( $opt->list && $mod )
      || !( $opt->list || $mod );
    $self->usage_error('--flex requires that you add a date')
      if $opt->flex && !$is_add;
    $self->usage_error('--tag requires that you add a date')
      if $opt->tag && !$is_add;
    $self->usage_error('the repetition flags require that you add a date')
      if $opt->repeat && !$is_add;
    $self->usage_error('vacation periods require descriptions')
      if $is_add && !defined $opt->add;
    $self->usage_error('no description provided')
      if $is_add && !@$args;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
