# Morning reservation notifier.
use strict;

use lib "/scripts";

use CQPerlExt;
use Time::Local;
use POSIX;
use Class::Struct;
use Net::SMTP;
use Date::Parse;
use Socket;
use Sys::Hostname;
use LMTCommon;
use LMTEmailer;
use LMTSession;
use LMTReservation;

my $lmtcommon  = new LMTCommon;
my $lmtemailer = new LMTEmailer;
my $baseUrl    = $lmtcommon->get( 'common', 'cqbaseurl' );
my $session    = LMTSession::open_session($lmtcommon);

$session->SetNameValue( "cronRunning", "yes" );

my @beginToday;
my @endToday;
my @beginTomorrow;
my @endTomorrow;
my @beginNextWeek;
my @endNextWeek;

my ( $next_week_rows, $next_week_start, $next_week_end, $next_week_month ) =
  LMTReservation::reservation_window( $session, 604800, 691200 );
LMTReservation::classify_window( $next_week_rows, $next_week_start,
    $next_week_end, "next_week",
    { begin => \@beginNextWeek, end => \@endNextWeek } );

my ( $near_rows, $today_unix, $tomorrow_unix ) =
  LMTReservation::reservation_window( $session, 0, 86400, $next_week_month );
LMTReservation::classify_window(
    $near_rows,
    $today_unix,
    $tomorrow_unix,
    "near",
    {
        begin_today    => \@beginToday,
        begin_tomorrow => \@beginTomorrow,
        end_today      => \@endToday,
        end_tomorrow   => \@endTomorrow,
    }
);

my $numBeginToday    = @beginToday;
my $numEndToday      = @endToday;
my $numBeginTomorrow = @beginTomorrow;
my $numEndTomorrow   = @endTomorrow;
my $numBeginNextWeek = @beginNextWeek;
my $numEndNextWeek   = @endNextWeek;

print $numBeginToday . " items in the BeginToday Queue\n";
print $numEndToday . " Items in the EndToday Queue\n";
print $numBeginTomorrow . " items in the BeginTomorrow Queue\n";
print $numEndTomorrow . " items in the EndTomorrow Queue\n";
print $numBeginNextWeek . " items in the BeginNextWeek Queue\n";
print $numEndNextWeek . " items in the endNextWeek Queue\n";

if ( $numBeginToday > 0 ) {
    handle_begin_today( \@beginToday );
}

my @notice_jobs = (
    {
        items         => \@endToday,
        label         => "handleEndToday",
        collect_ips   => 1,
        empty_ip_list =>
          "<em>No IP Addresses Associated with this Reservation</em>",
        ip_suffix =>
"<br />It is essential that you  <strong>STOP</strong> using these IP addresses after 10pm tonight!",
        subject_tail => " will end Tonight!",
        template     => "/scripts/email/morningReservationEndToday.html",
    },
    {
        items         => \@beginTomorrow,
        label         => "handleBeginTomorrow",
        collect_ips   => 0,
        fixed_ip_list =>
          "<em>None as reservation is in future - Begins Tomorrow</em>",
        subject_tail => " will BEGIN Tomorrow morning!",
        template     => "/scripts/email/morningReservationBeginTomorrow.html",
    },
    {
        items         => \@endTomorrow,
        label         => "handleEndTomorrow",
        collect_ips   => 1,
        empty_ip_list =>
          "<em>None currently associated with this reservation</em>",
        subject_tail => " will END Tomorrow!",
        template     => "/scripts/email/morningReservationEndTomorrow.html",
    },
    {
        items         => \@beginNextWeek,
        label         => "handleBeginNextWeek",
        collect_ips   => 0,
        fixed_ip_list =>
          "<em>None as reservation is in future - Begins Tomorrow</em>",
        subject_tail => " will BEGIN Tomorrow morning!",
        template     => "/scripts/email/morningReservationBeginNextWeek.html",
    },
    {
        items         => \@endNextWeek,
        label         => "handleEndNextWeek",
        collect_ips   => 1,
        empty_ip_list =>
          "<em>None currently associated with this reservation</em>",
        subject_tail => " en, first notification!",
        template     => "/scripts/email/morningReservationEndNextWeek.html",
    },
);

foreach my $job (@notice_jobs) {
    if ( @{ $job->{items} } > 0 ) {
        LMTReservation::handle_notices(
            %{$job},
            session      => $session,
            reservations => $job->{items},
            base_url     => $baseUrl,
            mailer       => $lmtemailer,
            common       => $lmtcommon,
        );
    }
}

sub handle_begin_today {
    my ($reservations) = @_;

    foreach my $reservation ( @{$reservations} ) {
        my $res_entity = $session->GetEntity( "Reservation", $reservation );
        my $reservation_begin =
          $res_entity->GetFieldValue("BeginDate")->GetValue();
        my $reservation_end = $res_entity->GetFieldValue("EndDate")->GetValue();
        my $headline = $res_entity->GetFieldValue("Headline")->GetValue();
        my $reservation_asset =
          $res_entity->GetFieldValue("AssetRef")->GetValue();
        my $reservation_crb = $res_entity->GetFieldValue("CRBRef")->GetValue();
        my $user_id         = $res_entity->GetFieldValue("User")->GetValue();
        my $user_entity     = $session->GetEntity( "users", $user_id );
        my $user_name  = $user_entity->GetFieldValue("fullname")->GetValue();
        my $user_email = $user_entity->GetFieldValue("email")->GetValue();
        my $reservation_ips =
          $res_entity->GetFieldValue("IPRef")->GetValueAsList();
        my $asset_title;
        my $asset_id;

        if ( $reservation_asset ne "" ) {
            my $asset_entity =
              $session->GetEntity( "Asset", $reservation_asset );

            if ( $asset_entity->GetFieldValue("state")->GetValue ne "Reserved" )
            {
                LMTSession::apply_action( $session, $asset_entity, "Reserved" );
            }

            $asset_title =
              $asset_entity->GetFieldValue("assetTitle")->GetValue();
            $asset_id = $asset_entity->GetFieldValue("id")->GetValue();
        }
        elsif ( $reservation_crb ne "" ) {
            my $crb_entity = $session->GetEntity( "EE_DUT", $reservation_crb );
            $asset_title = $crb_entity->GetFieldValue("Headline")->GetValue();
            $asset_id    = $crb_entity->GetFieldValue("id")->GetValue();
        }

        my @reservation_ip_addresses =
          LMTReservation::ip_addresses( $session, $reservation_ips );

        if ( $res_entity->GetFieldValue("state")->GetValue() eq "Submitted" ) {
            LMTSession::apply_action( $session, $res_entity, "Active" );
        }

        my $record = LMTReservation::build_record(
            id         => $reservation,
            headline   => $headline,
            user_name  => $user_name,
            user_email => $user_email,
            begin      => $reservation_begin,
            end        => $reservation_end,
            asset_name => $asset_title,
            asset_id   => $asset_id,
        );

        LMTReservation::print_reservation(
            "handleBeginToday", $reservation, $headline,
            $user_name,         $user_email,  $reservation_begin,
            $reservation_end,   $asset_title, $asset_id
        );
        LMTReservation::send_notice(
            session       => $session,
            reservation   => $record,
            ip_addresses  => \@reservation_ip_addresses,
            empty_ip_list =>
              "<em>None currently associated with this reservation</em>",
            subject_tail => " Begins Today!",
            template     => "/scripts/email/morningReservationBeginToday.html",
            base_url     => $baseUrl,
            mailer       => $lmtemailer,
            common       => $lmtcommon,
        );
    }

    return;
}
