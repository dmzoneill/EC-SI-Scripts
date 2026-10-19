# Export every ClearQuest CRB and asset row.
use strict;

use lib "/scripts";

use CQPerlExt;
use Socket;
use Sys::Hostname;
use POSIX qw(SIGALRM);
use Net::SMTP;
use English;
use LMTCommon;
use LMTSession;

my $lmtcommon = LMTCommon->new;
my $session   = LMTSession::open_session($lmtcommon);

open my $log, '>', '/scripts/log/LMTall.txt';

LMTSession::for_each_result(
    $session, "EE_DUT",
    [
        "id",                 "CRB_Location",
        "MACAddress1",        "State",
        "staticip.IPAddress", "CurrentUser.email",
    ],
    sub {
        my ($row)    = @_;
        my $id       = $row->GetColumnValue(1);
        my $location = $row->GetColumnValue(2);
        my $mac1     = $row->GetColumnValue(3);
        my $state    = $row->GetColumnValue(4);
        my $ip       = $row->GetColumnValue(5);
        my $email    = $row->GetColumnValue(6);
        print $log "crb|$id|$ip|$mac1|$location|$state|$email\n";
    }
);

LMTSession::for_each_result(
    $session, "ASSET",
    [ "id", "Location", "State", "MACAddress1", "ipAddress.IPAddress", ],
    sub {
        my ($row)    = @_;
        my $id       = $row->GetColumnValue(1);
        my $location = $row->GetColumnValue(2);
        my $state    = $row->GetColumnValue(3);
        my $mac      = $row->GetColumnValue(4);
        my $ip       = $row->GetColumnValue(5);
        print $log "asset|$id|$ip|$mac|$location|$state\n";
    }
);

close $log;
