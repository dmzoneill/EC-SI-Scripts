#!/usr/bin/perl
use strict;
use warnings;
use homecommon;

sub main
{
    my $whoami = `whoami`;
    chomp( $whoami );

    my $homelib = new homecommon( "/home" , $whoami );

    my %commands =  (
        
        "rm -rvf HOME/.ssh2/hostkeys/*.pub" , 0,
        "ypcat passwd | grep $whoami" , 1,
    );

    while( my ( $host , $foreignhome ) = each ( %{ $homelib->getHomes() } ) )
    {
        print "Updating $host\n";
        print " Performing => \n";
        
        while( my ( $cmd , $quiet ) = each( %commands ) )
        {
            $cmd =~ s/HOME/$cmd/g;
            
            my $ssh = "ssh $host \"" . $cmd . "\" 2>&1";
            my $result = `$ssh`;
           
            $result =~ s/^\s+//;
            $result =~ s/\s+$//;
            
            if( $quiet gt 1 )
            {
                print "  CMD : $ssh\n";
            }
            
            if( $quiet gt 0 )
            {
                print "  RST : $result\n";
            }
        }
        
        print "\n";
    }

}

main();

