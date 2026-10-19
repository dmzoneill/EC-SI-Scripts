# Night reservation notifier.
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

my $lmtcommon  = LMTCommon->new;
my $lmtemailer = LMTEmailer->new;
my $baseURL    = $lmtcommon->get( 'common', 'cqbaseurl' );
my $session    = LMTSession::open_session($lmtcommon);

$session->SetNameValue( "cronRunning", "yes" );

my @endToday;

my $reservation_query = $session->BuildQuery("Reservation");
$reservation_query->BuildField("ID");
$reservation_query->BuildField("BeginDate");
$reservation_query->BuildField("EndDate");

my ( undef, undef, undef, $mday, $mon, $year ) = localtime time;
my $today           = int( $mon + 1 ) . "/" . $mday . "/" . int( 1900 + $year );
my @date_filter     = ($today);
my @complete_filter = ("Complete");

my $complete_filter_op =
  $reservation_query->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
$complete_filter_op->BuildFilter( "state", $CQPerlExt::CQ_COMP_OP_NOT_IN,
    \@complete_filter );
$complete_filter_op->BuildFilter( "EndDate", $CQPerlExt::CQ_COMP_OP_LTE,
    \@date_filter );

my $today_unix = mktime( '0', '0', '0', $mday, $mon, $year );
my $result_set = $session->BuildResultSet($reservation_query);
$result_set->Execute();
my $status = $result_set->MoveNext();

while ( $status == 1 ) {
    push @endToday, $result_set->GetColumnValue(1);
    $status = $result_set->MoveNext();
}

my $num_end_today = @endToday;
printf( "%d items in the EndToday Queue\n\n", $num_end_today );

if ( @endToday > 0 ) {
    handle_end_today( \@endToday );
}

my $query_ip_def  = $session->BuildQuery("IPAddress");
my @submit_filter = ("true");
$query_ip_def->BuildField("id");
my $submit_filter_op =
  $query_ip_def->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
$submit_filter_op->BuildFilter( "isSubmit", $CQPerlExt::CQ_COMP_OP_NOT_IN,
    \@submit_filter );

my $result_ip_set = $session->BuildResultSet($query_ip_def);
$result_ip_set->Execute();
my $ip_status = $result_ip_set->MoveNext();

while ( $ip_status == 1 ) {
    my $entity_ip =
      $session->GetEntity( "IPAddress", $result_ip_set->GetColumnValue(1) );
    $session->EditEntity( $entity_ip, "Modify" );
    $entity_ip->SetFieldValue( "isSubmit", "true" );
    my $ip_edit_status = $entity_ip->Validate();

    if ( $ip_edit_status eq "" ) {
        $entity_ip->Commit();
    }
    else {
        $entity_ip->Revert();
    }

    $ip_status = $result_ip_set->MoveNext();
}

sync_reservations();

sub sync_reservations {
    my $active_query = $session->BuildQuery("Reservation");
    $active_query->BuildField("ID");
    $active_query->BuildField("AssetRef");

    my @active_filter = ('Active');
    my $active_filter_op =
      $active_query->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
    $active_filter_op->BuildFilter( "state", $CQPerlExt::CQ_COMP_OP_EQ,
        \@active_filter );
    $active_filter_op->BuildFilter( "AssetRef",
        $CQPerlExt::CQ_COMP_OP_IS_NOT_NULL, [""] );

    $result_set->Execute();
    my $row_status = $result_set->MoveNext();

    while ( $row_status == 1 ) {
        if ( $result_set->GetColumnValue(2) ne "" ) {
            my $asset_entity =
              $session->GetEntity( "Asset", $result_set->GetColumnValue(2) );
            LMTReservation::reserve_unless_reserved( $session, $asset_entity );
        }

        $row_status = $result_set->MoveNext();
    }

    return;
}

sub handle_end_today {
    my ($reservations) = @_;

    foreach my $reservation ( @{$reservations} ) {
        my $res_entity = $session->GetEntity( "Reservation", $reservation );
        my $begin      = $res_entity->GetFieldValue("BeginDate")->GetValue();
        my $end        = $res_entity->GetFieldValue("EndDate")->GetValue();
        my $headline   = $res_entity->GetFieldValue("Headline")->GetValue();
        my $asset      = $res_entity->GetFieldValue("AssetRef")->GetValue();
        my $crb        = $res_entity->GetFieldValue("CRBRef")->GetValue();
        my $ip_refs    = $res_entity->GetFieldValue("IPRef")->GetValueAsList();
        my @ip_addresses = LMTReservation::ip_addresses( $session, $ip_refs );
        my ( $asset_title, $asset_id ) =
          LMTReservation::asset_identity( $session, $asset, $crb );
        my $user_id     = $res_entity->GetFieldValue("User")->GetValue();
        my $user_entity = $session->GetEntity( "users", $user_id );
        my $user_name   = $user_entity->GetFieldValue("fullname")->GetValue();
        my $user_email  = $user_entity->GetFieldValue("email")->GetValue();
        my $record      = LMTReservation::build_record(
            id         => $reservation,
            headline   => $headline,
            user_name  => $user_name,
            user_email => $user_email,
            begin      => $begin,
            end        => $end,
            asset_name => $asset_title,
            asset_id   => $asset_id,
        );

        print "$asset_id\n";

        my $edit_result = $res_entity->EditEntity("Complete");
        my $res_status  = $res_entity->Validate();

        if ( $res_status eq "" ) {
            my $commit_status = $res_entity->Commit();
        }
        else {
            $res_entity->Revert();
        }
    }

    return;
}
