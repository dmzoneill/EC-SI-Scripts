package MmReport;

use strict;

use WWW::Curl::Easy;
use File::Slurp;
use MIME::Lite;
use Cwd qw(abs_path);

sub install_type_maps {
    my $typed = sub {
        my ( $self, $value, $name, $type, $attr ) = @_;
        $attr->{'xsi:type'} = $type;
        return [ $name, $attr, $value ];
    };

    *SOAP::Serializer::as_SortOrder     = $typed;
    *SOAP::Serializer::as_ObjRef        = $typed;
    *SOAP::Serializer::as_ObjectType    = $typed;
    *SOAP::Serializer::as_DNSRecordType = $typed;
    return;
}

sub write_rows {
    my ( $handle, $rows, $html_ref, $validity, $score_flags ) = @_;

    foreach my $record ( @{$rows} ) {
        my $refr  = $record->[0];
        my $name  = $record->[1];
        my $type  = $record->[2];
        my $val   = $record->[3];
        my $kcdb  = "";
        my $nodes = "";

        if ($score_flags) {
            $kcdb  = ( $record->[4] == 1 ) ? "yes" : "no";
            $nodes = ( $record->[5] == 1 ) ? "yes" : "no";
        }

        ${$html_ref} .=
            "<tr><td>"
          . $refr
          . "</td><td>"
          . $name
          . "</td><td>"
          . $type
          . "</td><td>"
          . $val
          . "</td><td>"
          . $kcdb
          . "</td><td>"
          . $nodes
          . "</td></tr>\n";
        print {$handle}
"\"$validity\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
    }

    return;
}

sub send_report {
    my (%args)    = @_;
    my $subnet    = $args{subnet};
    my $path      = abs_path($0);
    my $good_html = "";
    my $bad_html  = "";
    my $hostname  = `uname -n`;
    chomp $hostname;
    my $html_body = read_file('report.html');

    if ( open my $csv, '>', "$subnet.csv" ) {
        print {$csv}
"\"Validity\",\"M&M ID\",\"Record\",\"Type\",\"Value\",\"Kcdb\",\"Nodes\"\n";
        write_rows( $csv, $args{up},         \$good_html, "yes", 1 );
        write_rows( $csv, $args{cname_up},   \$good_html, "yes", 0 );
        write_rows( $csv, $args{txt_up},     \$good_html, "yes", 0 );
        write_rows( $csv, $args{rp_up},      \$good_html, "yes", 0 );
        write_rows( $csv, $args{down},       \$bad_html,  "no",  1 );
        write_rows( $csv, $args{cname_down}, \$bad_html,  "yes", 0 );
        write_rows( $csv, $args{txt_down},   \$bad_html,  "yes", 0 );
        write_rows( $csv, $args{rp_down},    \$bad_html,  "yes", 0 );
        close $csv;

        $path = $hostname . ":" . $path;
        $html_body =~ s/R_SUBNET/$subnet/g;
        $html_body =~ s/R_BADRECORDS/$bad_html/g;
        $html_body =~ s/R_GOODRECORDS/$good_html/g;
        $html_body =~ s/R_LOCATION/$path/g;
        $html_body =~ s/R_USER/$args{username}/g;

        my $recipient = $args{recipients}->{"$subnet"};
        my $msg       = MIME::Lite->new(
            From    => "$args{from}",
            To      => "$recipient",
            Cc      => '',
            Subject =>
              "Men & Mice $subnet / Kcdb / Nodes Cross Reference Report",
            Type => 'multipart/related'
        );

        $msg->attach(
            Type => 'text/html',
            Data => qq
						{
							$html_body
						},
        );

        $msg->attach(
            Type => 'image/jpeg',
            Path => '/home/dmoneil2/scripts/menandmice/intel-small.jpg',
            Id   => 'intel-small.jpg',
        );

        $msg->attach(
            Type        => 'text/csv',
            Path        => "$subnet.csv",
            Filename    => "$subnet.csv",
            Disposition => 'attachment'
        );

        $msg->send;
        my $cleanup = `rm -rvf *.csv`;
    }

    return;
}

sub kcdb_probe {
    my ( $username, $password, $fqdn, $body_ref ) = @_;
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt( CURLOPT_USERAGENT,
"Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; .NET CLR 1.1.4322; .NET4.0C; .NET4.0E; InfoPath.3; Zune 4.7; MS-RTC LM 8)"
    );
    $curl->setopt( CURLOPT_URL,
        'http://kcdb.intel.com/Dashboard/includes/Dashboard.ajax.asp' );
    $curl->setopt( CURLOPT_POST,       1 );
    $curl->setopt( CURLOPT_HTTPAUTH,   CURLAUTH_NTLM );
    $curl->setopt( CURLOPT_USERPWD,    "$username:$password" );
    $curl->setopt( CURLOPT_POSTFIELDS, "task=getObjList&ObjName=%25" . $fqdn );
    $curl->setopt( CURLOPT_WRITEDATA,  $body_ref );

    my $retcode = $curl->perform;

    if ( $retcode == 0 ) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        chomp ${$body_ref};

        if ( ${$body_ref} =~ /[0-9]+\|$fqdn(.*)\[i]\|/ ) {
            return 1;
        }
    }
    else {
        print "An error happened: $retcode "
          . $curl->strerror($retcode) . " "
          . $curl->errbuf . "\n";
    }

    return 0;
}

sub check_kcdb {
    my ( $username, $password, $hostname ) = @_;
    my $response_body = "";

    if (
        kcdb_probe(
            $username,                   $password,
            $hostname . ".ir.intel.com", \$response_body
        )
      )
    {
        return 1;
    }

    if (
        kcdb_probe(
            $username,                         $password,
            $hostname . ".ger.corp.intel.com", \$response_body
        )
      )
    {
        return 1;
    }

    return 0;
}

sub attach_related_records {
    my (
        $dns_records, $total_results, $source_rows,
        $rp_rows,     $txt_rows,      $cname_rows
    ) = @_;

    for ( my $counter = 0 ; $counter < $total_results ; $counter++ ) {
        my $record_row = $dns_records->[0]->{'dnsRecord'}[$counter];
        my $r_refr     = $record_row->{'ref'};
        my $r_name     = $record_row->{'name'};
        my $r_type     = $record_row->{'type'};
        my $r_data     = $record_row->{'data'};

        foreach my $record ( @{$source_rows} ) {
            my $name = $record->[1];
            my $type = $record->[2];

            if ( $r_name =~ /$name/i && $r_type =~ /RP/i ) {
                push @{$rp_rows},
                  [ $r_refr, $r_name, $r_type, $r_data, -1, -1 ];
            }

            if ( $r_name =~ /$name/i && $r_type =~ /TXT/i ) {
                push @{$txt_rows},
                  [ $r_refr, $r_name, $r_type, $r_data, -1, -1 ];
            }

            if ( $r_data =~ /$name/i && $r_type =~ /CNAME/i ) {
                push @{$cname_rows},
                  [ $r_refr, $r_name, $r_type, $r_data, -1, -1 ];
            }
        }
    }

    return;
}

1;
