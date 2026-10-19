use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;

use WWW::Curl::Easy;
use SOAP::Lite;
use File::Slurp;
use MIME::Lite;
use Net::SMTP;
use Time::HiRes qw(usleep);
use IO::Prompt;
use Cwd qw(abs_path);
use MmReport;

MmReport::install_type_maps();

my $central   = "ipamdb.intel.com";
my $web       = "ipam.intel.com";
my $zonename  = "ir.intel.com.";
my $mail_host = 'mailhost.ir.intel.com';
my $from      = 'sie.it@intel.com';

my @subnets = (
    "10.237.217", "10.243.17",  "10.243.18",  "10.237.216",
    "10.237.214", "10.237.213", "10.237.212", "10.243.22",
    "10.243.23"
);
my %recipients = (
    "10.237.217" => 'david.m.oneill@intel.com',
    "10.243.17"  => 'david.m.oneill@intel.com',
    "10.243.18"  => 'david.m.oneill@intel.com',
    "10.237.216" => 'david.m.oneill@intel.com',
    "10.237.214" => 'david.m.oneill@intel.com',
    "10.237.213" => 'david.m.oneill@intel.com',
    "10.237.212" => 'david.m.oneill@intel.com',
    "10.243.22"  => 'david.m.oneill@intel.com',
    "10.243.23"  => 'david.m.oneill@intel.com'
);
my @report_up         = ();
my @report_down       = ();
my @report_cname_up   = ();
my @report_cname_down = ();
my @report_rp_up      = ();
my @report_rp_down    = ();
my @report_txt_up     = ();
my @report_txt_down   = ();

my $domain   = prompt('DOMAIN : ');
my $idsid    = prompt('IDSID : ');
my $username = "$domain\\$idsid";
my $pw       = prompt 'Password : ', -echo => '*';
my $password = "" . $pw;

sub checknodes {
    my $ip = shift;
    my $nodecmd =
        "ucat nodes | grep \""
      . $ip
      . " \" | awk '{split(\$0,parts,\" \")} END{print parts[1]}' | awk '{split(\$0,parts,\"=\")} END{print parts[2]}'";
    $nodecmd = `$nodecmd`;
    chomp $nodecmd;

    if ( $nodecmd !~ /[0-9a-zA-Z]+/ ) {
        return 0;
    }

    return 1;
}

my $service =
  SOAP::Lite->service(
    'http://' . $web . '/_mmwebext/mmwebext.dll?wsdl?server=' . $central );
my $sessionid = $service->Login( $central, $username, $password, 0 );

print "Session id : " . $sessionid . "\n";

if ( $sessionid ne "" ) {
    print "Connected\n";
    my @result =
      $service->GetDNSZones( $sessionid, "name:\^$zonename\$ type:\^master\$",
        0, 0, 'name', SOAP::Data->type( "SortOrder" => 'Ascending' ) );
    my $total_results = $result[-1];

    if ( $total_results gt 1 ) {
        print "More than one zone returned - stop!\n";
        exit 0;
    }

    if ( $total_results eq 0 ) {
        print "Zone with name $zonename not found - stop!\n";
        exit 0;
    }

    print "Found Zone\n";

    my $dns_zone_ref = $result[0]->{'dnsZone'}->{'ref'};
    my @records =
      $service->GetDNSRecords( $sessionid,
        SOAP::Data->type( "ObjRef" => $dns_zone_ref ),
        '', 0, 0, 0, 'name', SOAP::Data->type( "SortOrder" => 'Ascending' ) );

    print "Got Records\n";

    $total_results = $records[-1];

    foreach my $subnet (@subnets) {
        @report_up         = ();
        @report_down       = ();
        @report_cname_up   = ();
        @report_cname_down = ();
        @report_rp_up      = ();
        @report_rp_down    = ();
        @report_txt_up     = ();
        @report_txt_down   = ();

        print "Analysing $subnet\n";

        for ( my $counter = 0 ; $counter < $total_results ; $counter++ ) {
            my $record_row = $records[0]->{'dnsRecord'}[$counter];
            my $r_refr     = $record_row->{'ref'};
            my $r_name     = $record_row->{'name'};
            my $r_type     = $record_row->{'type'};
            my $r_data     = $record_row->{'data'};

            if ( $r_data =~ m/$subnet/i ) {
                my $simple_scan =
"/usr/bin/nmap -p T:22,139 -R $r_data | grep \"host up\" | wc -l";
                my $scan = `$simple_scan`;
                chomp $scan;

                my $kcdb =
                  MmReport::check_kcdb( $username, $password, $r_name );
                my $nodes = checknodes($r_data);

                if ( $scan eq "1" ) {
                    push @report_up,
                      [ $r_refr, $r_name, $r_type, $r_data, $kcdb, $nodes ];
                }
                else {
                    push @report_down,
                      [ $r_refr, $r_name, $r_type, $r_data, $kcdb, $nodes ];
                }

                printf( "%20s %25s %3s %18s\n",
                    $r_refr, $r_name, $r_type, $r_data );
                usleep 100000;
            }
        }

        MmReport::attach_related_records( \@records, $total_results,
            \@report_down, \@report_rp_down, \@report_txt_down,
            \@report_cname_down );
        MmReport::attach_related_records(
            \@records,      $total_results,  \@report_up,
            \@report_rp_up, \@report_txt_up, \@report_cname_up
        );

        MmReport::send_report(
            subnet     => $subnet,
            up         => \@report_up,
            down       => \@report_down,
            cname_up   => \@report_cname_up,
            cname_down => \@report_cname_down,
            rp_up      => \@report_rp_up,
            rp_down    => \@report_rp_down,
            txt_up     => \@report_txt_up,
            txt_down   => \@report_txt_down,
            username   => $username,
            recipients => \%recipients,
            from       => $from,
        );
    }

    $service->Logout($sessionid);
}
