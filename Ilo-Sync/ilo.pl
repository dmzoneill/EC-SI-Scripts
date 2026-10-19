#!/usr/binperl

use strict;
use warnings;

use FindBin;
use lib $FindBin::Bin;

use WWW::Curl::Easy;
use File::Slurp;
use Sys::Hostname;
use IO::Prompt;
use Cwd        qw(abs_path);
use File::Temp qw(tempfile);
use IloClient;

#
# Asks user for input
# @param string Question to ask
# @param string Default answer
# @param int hash out with asterix
# @return string user inputted value
#################################################################################################################

sub requestInput {
    my ( $question, $default, $sensitive ) = @_;
    my $retval = "";

    if ( $sensitive == 0 ) {
        $retval .= prompt( $question . " [$default]: " );
    }
    else {
        $retval .= prompt( $question . " : ", -echo => '*' );
    }

    return $retval;
}

#
# Get the ILO version
# @param string fqdn
# @return int 2/3
################################################################################################################

sub getIloVersion {
    my $hostname = shift;
    my ( $fh, $filename ) = tempfile();
    my $curl = IloClient::new_curl(
        "https://" . $hostname . "/ribcl",
        "<RIBCL VERSION=\"2.0\"></RIBCL>"
    );
    my ( $retcode, $response_body ) =
      IloClient::read_response( $curl, $fh, $filename );

    if ( $response_body =~ m/HTTP.1.1 200 OK/ ) {
        return 3;
    }

    return 2;
}

#
# Push xml config file to the ilo
# @param string fqdn
# @param string xml config to push
#################################################################################################################

sub push2Ilo2Config {
    my ( $hostname, $iloversion, $config, $name, $verbose ) = @_;

    my $curl;
    my $retcode;
    my ( $fh, $filename ) = tempfile();
    my $queryString = "";

    my @lines = split( /\n/, $config );

    my $newconfig = "";

    foreach my $line (@lines) {
        $line =~ s/\r|\n//g;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;

        if ( $line =~ m/xml version/ ) {
            $newconfig .= $line . "\r\n";
        }
        elsif ( $line =~ m/LOGIN USER_LOGIN/ ) {
            $newconfig .= "\r\n" . $line . "\r\n";
        }
        else {
            $newconfig .= $line;
        }
    }

    $newconfig .= "\n";

    $curl = IloClient::new_curl( "https://" . $hostname . $queryString,
        "$newconfig" );
    my $response_body;
    ( $retcode, $response_body ) =
      IloClient::read_response( $curl, $fh, $filename );
    IloClient::report_result( $response_body, $hostname, $name, $verbose );
}

#
# Push xml config file to the ilo
# @param string fqdn
# @param string xml config to push
#################################################################################################################

sub push2Ilo3Config {
    my ( $hostname, $iloversion, $config, $name, $verbose ) = @_;

    my $curl;
    my $retcode;
    my ( $fh, $filename ) = tempfile();
    my $queryString = "/ribcl";

    $curl = IloClient::new_curl( "https://" . $hostname . $queryString,
        $config . "\r\n" );
    my $response_body;
    ( $retcode, $response_body ) =
      IloClient::read_response( $curl, $fh, $filename );
    IloClient::report_result( $response_body, $hostname, $name, $verbose );
}

#
# Main
# Takes user credentials and iterates the hosts in the file!
# Pushing confoiguration to them
# @param array args
#################################################################################################################

sub main {
    my @args    = shift;
    my $verbose = 0000000000;

    # Hosts Read from file
    my $filecontents = read_file("ilo.txt");
    my @hosts        = split( /\n/, $filecontents );
    my @xmlconfigs   = ( "ilodirectory.xml", "ilousers.xml" );

    # Request Ilo Login Credentials
    my $domain = requestInput( "Domain", "", 0 );
    my $idsid  = requestInput( "Idsid",  "", 0 );
    my $login  = ( $domain eq "" ) ? "$idsid" : "$domain\\$idsid";
    my $pw     = requestInput( "Password", "", 1 );

    foreach my $ilohost (@hosts) {
        $ilohost =~ s/^\s+//;
        $ilohost =~ s/\s+$//;

        if ( $ilohost eq "" || $ilohost !~ m/-rpm/ ) {
            next;
        }

        $ilohost .= ":443";

        my $iloversion = getIloVersion( $ilohost, $verbose );

        my @hostbits = split( /\./, $ilohost );
        my $host     = $hostbits[0];

        foreach my $configFile (@xmlconfigs) {
            my $iloconf = read_file($configFile);
            $iloconf =~ s/\[ilouser\]/$login/g;
            $iloconf =~ s/\[ilopass\]/$pw/g;
            $iloconf =~ s/\[host\]/$host/g;

            if ( $iloversion == 2 ) {
                push2Ilo2Config( $ilohost, $iloversion, $iloconf, $configFile,
                    $verbose );
            }
            elsif ( $iloversion == 3 ) {
                push2Ilo3Config( $ilohost, $iloversion, $iloconf, $configFile,
                    $verbose );
            }
        }
    }
}

main($ARGV);

