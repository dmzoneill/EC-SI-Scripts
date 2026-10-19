# Sync active reservations with the Reserved state of their assets.
use strict;

use lib "/scripts";

use CQPerlExt;
use LMTCommon;
use LMTSession;
use LMTReservation;

my $lmtcommon = LMTCommon->new;
my $session   = LMTSession::open_session($lmtcommon);

sync_reservations();

sub sync_reservations {
    my $reservation_query = $session->BuildQuery("Reservation");
    $reservation_query->BuildField("ID");
    $reservation_query->BuildField("AssetRef");

    my @active_filter = ('Active');
    my $active_filter =
      $reservation_query->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
    $active_filter->BuildFilter( "state", $CQPerlExt::CQ_COMP_OP_EQ,
        \@active_filter );
    $active_filter->BuildFilter( "AssetRef", $CQPerlExt::CQ_COMP_OP_IS_NOT_NULL,
        [""] );

    my $result_set = $session->BuildResultSet($reservation_query);
    $result_set->Execute();
    my $status = $result_set->MoveNext();

    while ( $status == 1 ) {
        my $asset_entity =
          $session->GetEntity( "Asset", $result_set->GetColumnValue(2) );
        LMTReservation::reserve_unless_reserved( $session, $asset_entity );
        $status = $result_set->MoveNext();
    }

    my $asset_query = $session->BuildQuery("Asset");
    $asset_query->BuildField("id");
    $asset_query->BuildField("reservations");

    my @reserved_filter     = ('Reserved');
    my @reservations_filter = ('');
    my $reserved_filter_op =
      $asset_query->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
    $reserved_filter_op->BuildFilter( "state", $CQPerlExt::CQ_COMP_OP_EQ,
        \@reserved_filter );

    $result_set = $session->BuildResultSet($asset_query);
    $result_set->Execute();
    $status = $result_set->MoveNext();

    while ( $status == 1 ) {
        if ( $result_set->GetColumnValue(2) eq "" ) {
            my $asset_entity =
              $session->GetEntity( "Asset", $result_set->GetColumnValue(1) );
            LMTSession::apply_action( $session, $asset_entity, "Available" );
        }

        $status = $result_set->MoveNext();
    }

    return;
}
