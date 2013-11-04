#!/usr/bin/perl
use strict;
use warnings;
use homecommon;


sub main
{
    my $whoami = `whoami`;
    chomp( $whoami );

    my $homelib = new homecommon( "/home" , $whoami );
    
    my %files = (
        ".ssh2/*" , ".ssh2/",
        "*$whoami" , "",
        ".vi*" , "",
        ".itools" , "",
        ".vnc/xstartup" , ".vnc/",
    );

    while( my ( $host , $foreignhome ) = each ( %{ $homelib->getHomes() } ) )
    {
        print "Pushing updates to $host\n";
        print " Copying => ";

        while( my ( $src , $dest ) = each ( %files ) )
        {
            print $src . " ";
            my $scp = "scp -r " . $homelib->getHome() . "/" . $src . " " . $host . ":" . $foreignhome . "/" . $dest . " 2>&1";
            my $result = `$scp`;
        }

        print "\n";
    }
}

main();

