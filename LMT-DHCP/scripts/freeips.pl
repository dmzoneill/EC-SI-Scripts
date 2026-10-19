use strict;

use lib "/scripts";

use CQPerlExt;
use LMTCommon;
use LMTEmailer;
use LMTSession;

my $lmtcommon  = LMTCommon->new;
my $lmtemailer = LMTEmailer->new;
my $baseURL    = $lmtcommon->get( 'common', 'cqbaseurl' );
my $session    = LMTSession::open_session($lmtcommon);

my @vlan1 = ( "10.237.212.", 212 );
my @vlan2 = ( "10.237.213.", 213 );
my @vlan3 = ( "10.237.214.", 214 );
my @vlan4 = ( "10.243.18.",  18 );
my @vlans = ( \@vlan1, \@vlan2, \@vlan3, \@vlan4 );

my $ipfreedata = "";

foreach my $vlan (@vlans) {
    my @statefilter = ("Free");
    my @ipfilter    = ( $vlan->[0] );

   # Create A Query that Gets all Reservations that Start/End Today and Tomorrow
    my $reservationQuery = $session->BuildQuery("IPAddress");
    $reservationQuery->BuildField("id");
    $reservationQuery->BuildField("IPAddress");

    my $query_CompleteFilter =
      $reservationQuery->BuildFilterOperator($CQPerlExt::CQ_BOOL_OP_AND);
    $query_CompleteFilter->BuildFilter( "State", $CQPerlExt::CQ_COMP_OP_EQ,
        \@statefilter );
    $query_CompleteFilter->BuildFilter( "IPAddress",
        $CQPerlExt::CQ_COMP_OP_LIKE, \@ipfilter );

    my $resultSet = $session->BuildResultSet($reservationQuery);
    $resultSet->Execute();

    # You can use this one line:
    my $rows = $resultSet->ExecuteAndCountRecords();

    $ipfreedata .= $vlan->[1] . "," . $rows . "|";
}

$ipfreedata = `echo '$ipfreedata' > /var/www/html/logs/freeips.txt`;
