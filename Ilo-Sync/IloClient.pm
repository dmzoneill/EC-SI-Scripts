package IloClient;

use strict;
use warnings;

use WWW::Curl::Easy;

sub new_curl {
    my ( $url, $body ) = @_;
    my $curl = WWW::Curl::Easy->new;
    $curl->setopt( CURLOPT_USERAGENT,
"Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; MS-RTC LM 8)"
    );
    $curl->setopt( CURLOPT_SSL_VERIFYPEER, 0 );
    $curl->setopt( CURLOPT_URL,            $url );
    $curl->setopt( CURLOPT_POST,           1 );
    $curl->setopt( CURLOPT_HEADER,         1 );
    $curl->setopt( CURLOPT_POSTFIELDS,     $body );
    return $curl;
}

sub read_response {
    my ( $curl, $handle, $filename ) = @_;
    $curl->setopt( CURLOPT_WRITEDATA, \$handle );
    my $retcode       = $curl->perform;
    my $response_body = `cat $filename`;
    return ( $retcode, $response_body );
}

sub report_result {
    my ( $response_body, $hostname, $name, $verbose ) = @_;

    if ( $response_body =~ /failed/ ) {
        print "Failed : $hostname - > $name \n";
    }
    else {
        print "Success : $hostname - > $name \n";
    }

    if ( $verbose == 1 ) {
        print $response_body . "\n\n";
    }

    return;
}

1;
