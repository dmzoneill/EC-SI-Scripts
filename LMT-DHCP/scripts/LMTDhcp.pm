package LMTDhcp;

use strict;

use English;

sub check_ip_address {
    my ( $ip, $vlan, $id ) = @_;

    if ( $ip =~
/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
      )
    {
        my @octets = split /\./, $ip;

        if ( $octets[2] == $vlan ) {
            return $ip;
        }

        return 0;
    }

    return -1;
}

sub check_mac_address {
    my ( $mac, $id ) = @_;

    if ( $mac =~ /^(([0-9a-fA-F]{2}[:-]{1}){5}([0-9a-fA-F]{2}))$/ ) {
        return 1;
    }

    return 0;
}

sub emit_lease {
    my (
        $fh,   $lab, $id,      $mac,       $ipaddr, $vlan,
        $root, $ok,  $iperror, $vlanerror, $macerror
    ) = @_;

    if ( check_mac_address( $mac, $id ) != 0 || $lab eq "NTS" ) {
        my $ip = check_ip_address( $ipaddr, $vlan, $id );

        if ( $ip eq $ipaddr || $lab eq "NTS" ) {
            print $ok;
            print {$fh} "$id $mac $ipaddr $root\n";
        }
        elsif ( $ip == -1 ) {
            print $iperror;
        }
        else {
            print $vlanerror;
        }
    }
    else {
        print $macerror;
    }

    return;
}

sub read_text_file {
    my ($path) = @_;

    if ( open my $handle, '<', $path ) {
        my $data;
        $data .= $ARG while (<$handle>);
        close $handle;
        return ( 1, $data );
    }

    return ( 0, undef );
}

1;
