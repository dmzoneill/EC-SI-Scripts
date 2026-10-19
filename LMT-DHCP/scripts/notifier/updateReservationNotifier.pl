# Reservation update notifier.
use strict;

use lib "/scripts";

use CQPerlExt;
use Time::Local;
use POSIX;
use Class::Struct;
use Net::SMTP;
use Date::Parse;
use LMTCommon;
use LMTEmailer;
use LMTSession;

my $lmtcommon  = LMTCommon->new;
my $lmtemailer = LMTEmailer->new;
my $session    = LMTSession::open_session($lmtcommon);

sub in_array {
    my ( $arr, $search_for ) = @_;
    my %items = map { $_ => 1 } @$arr;
    return ( exists $items{$search_for} ) ? 1 : 0;
}

my @notified_assets = ();
my @notified_ips    = ();

scan_reservations( "AssetRef.id", "AssetRef.AssetTitle", "Asset",
    \@notified_assets );
scan_reservations( "CRBRef.id", "CRBRef.Headline", "CRB", \@notified_ips );

sub scan_reservations {
    my ( $id_field, $title_field, $kind, $seen ) = @_;
    my $submitted_query = $session->BuildQuery("Reservation");
    $submitted_query->BuildField("ID");
    $submitted_query->BuildField("Headline");
    $submitted_query->BuildField("State");
    $submitted_query->BuildField("BeginDate");
    $submitted_query->BuildField("EndDate");
    $submitted_query->BuildField("Project");
    $submitted_query->BuildField($id_field);
    $submitted_query->BuildField($title_field);
    $submitted_query->BuildField("history.action_timestamp");
    $submitted_query->BuildField("User.fullname");
    $submitted_query->BuildField("User.email");
    $submitted_query->BuildField("history.action_timestamp");
    $submitted_query->BuildField("IPRef.IPAddress");

    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime time;
    my $result_set = $session->BuildResultSet($submitted_query);
    $result_set->Execute();
    my $status = $result_set->MoveNext();

    while ( $status == 1 ) {
        my $res_id         = $result_set->GetColumnValue(1);
        my $res_headline   = $result_set->GetColumnValue(2);
        my $res_state      = $result_set->GetColumnValue(3);
        my $res_begin      = $result_set->GetColumnValue(4);
        my $res_end        = $result_set->GetColumnValue(5);
        my $res_project    = $result_set->GetColumnValue(6);
        my $asset_id       = $result_set->GetColumnValue(7);
        my $asset_headline = $result_set->GetColumnValue(8);
        my $res_timestamp  = $result_set->GetColumnValue(9);
        my $res_fullname   = $result_set->GetColumnValue(10);
        my $res_email      = $result_set->GetColumnValue(11);
        my $last_modified  = $result_set->GetColumnValue(12);
        my $res_ip         = $result_set->GetColumnValue(13);
        my $start =
            ( int($year) + 1900 ) . "-"
          . ( int($mon) + 1 ) . "-"
          . $mday . " "
          . $hour . ":"
          . $min . ":"
          . $sec;
        my ( $years, $months, $days, $hours, $mins, $secs ) =
          split /\W+/, $last_modified;
        my $stop =
            $years . "-"
          . $months . "-"
          . $days . " "
          . $hours . ":"
          . $mins . ":"
          . $secs;
        my $diff = str2time($start) - str2time($stop);

        if ( $diff < 360 && $diff > -60 ) {
            print "Asset reservation\n";
            printf "It was modified %d seconds ago\n", $diff;
            print "Reservation id : $res_id\n";
            print "Reservation Headline : $res_headline\n";
            print "Reservation State : $res_state\n";
            print "Reservation Begin : $res_begin\n";
            print "Reservation End : $res_end\n";
            print "Reservation Project : $res_project\n";
            print "Asset id : $asset_id\n";
            print "Asset Headline : $asset_headline\n";
            print "Asset IP : $res_ip\n";
            print "Reservation timestamp : $res_timestamp\n";
            print "Reservation Fullname : $res_fullname\n";
            print "Reservation Email : $res_email\n";

            if ( $asset_id ne "" ) {
                send_reservation_email(
                    $res_id,        $res_headline,   $res_state,
                    $res_begin,     $res_end,        $res_project,
                    $asset_id,      $asset_headline, $res_ip,
                    $res_timestamp, $res_fullname,   $res_email,
                    $kind
                );
            }

            push @{$seen}, '$assetID';
        }

        $status = $result_set->MoveNext();
    }

    return;
}

sub send_reservation_email {
    my $res_id        = shift;
    my $res_headline  = shift;
    my $res_state     = shift;
    my $res_begin     = shift;
    my $res_end       = shift;
    my $res_project   = shift;
    my $id            = shift;
    my $headline      = shift;
    my $ip            = shift;
    my $res_timestamp = shift;
    my $res_fullname  = shift;
    my $res_email     = shift;
    my $type          = shift;
    my $ip_list;

    # Original subject and ASSETHEADLINE read unset names, so they stay empty.
    my $res_headline_legacy;
    my $asset_headline_legacy;

    if ( $ip ne "" ) {
        $ip_list = "<strong>" . $ip . "</strong>";
    }
    else {
        $ip_list = "<em>No IP Addresses Associated with this Reservation</em>";
    }

    my $subject =
        " Reservation "
      . $res_headline_legacy
      . " Has Been Submitted / Modified!";

    $lmtemailer->loadTemplate("/scripts/email/updateReservationNotifier.html");
    $lmtemailer->setSubject(
        $lmtcommon->get( 'emailoptions', 'email_subject-prefix' ) . $subject );
    $lmtemailer->setSendTo(
        $res_email . "," . $lmtcommon->get( 'contacts', 'email_level1' ) );
    $lmtemailer->setSendFrom( $lmtcommon->get( 'contacts', 'email_level1' ) );

    my %replace = (
        "RESFULLNAME",   $res_fullname,
        "TYPE",          $type,
        "ASSETHEADLINE", $asset_headline_legacy,
        "IDNO",          $id,
        "HEADLINE",      $headline,
        "IPLIST",        $ip_list,
        "RESHEADLINE",   $res_headline,
        "RESID",         $res_id,
        "RESBEGIN",      $res_begin,
        "RESEND",        $res_end,
    );

    $lmtemailer->replaceThese(%replace);
    $lmtemailer->sendEmail();
    return;
}
