package App::JobLog::Command::note;

# ABSTRACT: take a note

use App::JobLog -command;
use Modern::Perl;
use autouse 'Getopt::Long::Descriptive' => qw(prog_name);
use Class::Autouse qw(App::JobLog::Log);

sub execute {
    my ( $self, $opt, $args ) = @_;
    my $tags = $opt->tag;
    my $log  = App::JobLog::Log->new;
    unless ( $tags || $opt->clear_tags ) {
        my ($last) = $log->last_note;
        $tags = $last->tags if $last;
    }
    $log->append_note(
        $tags ? ( tags => $tags ) : (),
        description => [ join ' ', @$args ],
    );
}

sub usage_desc { '%c ' . __PACKAGE__->name . ' <text of note>' }

sub abstract { 'take a note' }

sub full_description {
    <<END;
Take a note. E.g.,

  @{[prog_name($0)]} @{[__PACKAGE__->name]} remember to get kids from school

All arguments that are not parameter values are concatenated as the note. Notes
have a time but not a duration. See the summary command for how to extract notes
from the log.

Notes may be tagged to assist in search or categorization.
END
}

sub options {
    return (
        [
            'tag|t=s@',
'tag the note; multiple tags are acceptable; e.g., -t foo -t bar -t quux',
        ],
        [
            'clear-tags|T',
            'inherit no tags from preceding note; '
              . 'this is equivalent to -t ""; '
              . 'this option has no effect if any tag is specified',
        ],

    );
}

sub validate {
    my ( $self, $opt, $args ) = @_;

    $self->usage_error('no note provided') unless @$args;
}

1;

__END__

=pod

=head1 SYNOPSIS

=head1 DESCRIPTION


=head2 TAGS

You may optionally attach categories to tasks with tags. Any string can be a tag but to make the output readable you'll want them
to be short. Also, in the logs tags are delimited by whitespace and separated from the timestamp and description by colons, so
these characters will be escaped with a slash. If you edit the log by hand and forget to escape these characters the log will
still parse but you will be surprised by the summaries you get.

You may specify multiple tags, but each one needs its own B<--tag> flag.

If you don't specify otherwise the new note will inherit the tags of the previous note, so you will need to apply
the B<--clear-tags> option to prevent this. The reasoning behind this feature is that when you take notes you frequently take
several in succession and want them all tagged the same way.

=cut
