package App::JobLog::Command::vacation;

# ABSTRACT: controller for vacation dates

use Modern::Perl;
use App::JobLog -command;

sub execute {
    my ( $self, $opt, $args ) = @_;

    print "(vacation) Everything has been initialized.  (Not really.)\n";
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
        [ 'add|a=s',  'add date or range; e.g., -a "May 17, 1951"' ],
        [
            'delete|d=i',
            'delete date with given index in list (see --list); e.g., -d 1'
        ],
    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    my $error = '';
    $error = 'either list or modify'
      if $opt->{list} && ( $opt->{add} || $opt->{delete} );
    $error ||= '--flex requires that you add a date'
      if $opt->{flex} && !$opt->{add};
    $error ||= '--tag requires that you add a date'
      if $opt->{tag} && !$opt->{add};
    $self->usage_error($error) if $error;
}

1;

__END__

=pod

=head1 DESCRIPTION

This wasn't written to be used outside of C<App::JobLog>. The code itself contains interlinear comments if
you want the details.

=cut
