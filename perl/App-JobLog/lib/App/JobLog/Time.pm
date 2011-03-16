package App::JobLog::Time;

# ABSTRACT: consolidates basic time functions into one location

=head1 DESCRIPTION

C<App::JobLog::Time> puts the cachable time functions into a common module
to improve efficiency and facilitate testing.

=cut

use Exporter 'import';
our @EXPORT_OK = qw(
  now
  today
  tz
);

use Modern::Perl;
use DateTime;
use DateTime::TimeZone;
use App::JobLog::Config qw(time_zone);

# cached values
our ( $today, $now, $tz );

=method now

The present moment with the time zone set to C<$App::JobLog::Time::tz>. This
may be overridden with C<$App::JobLog::Time::now>.

=cut

sub now {
    $now //= DateTime->now( time_zone => tz() );
    return $now->clone;
}

=method today

Unless C<$App::JobLog::Time::today> has been set, whatever is given by C<now>
truncated to the day.

=cut

sub today {
    $today //= now()->truncate( to => 'day' );
    return $today->clone;
}

=method tz

Returns time zone, which will be the local time zone unless C<$App::JobLog::Time::tz>
has been set.

=cut

sub tz {
    $tz //= DateTime::TimeZone->new( name => time_zone );
    return $tz;
}

1;
