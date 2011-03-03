package App::JobLog;
use App::Cmd::Setup -app;

# ABSTRACT: base of work log application

=head1 DESCRIPTION

C<App::JobLog> is a minimal extension of L<App::Cmd>. All it adds to a vanilla
instance of this class is all unambiguous aliases of basic commands.

=cut

sub allow_any_unambiguous_abbrev { 1 }

1;
