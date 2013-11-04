#!/usr/bin/perl
use strict;
use warnings;

package homecommon;

sub new
{
    my ( $class , $homedir , $user ) = @_;

    my %paths = (
        "pb-login.pb.intel.com" , "/nfs/pb/home/" . $user,
        "iil-login.iil.intel.com" , "/nfs/iil/disks/home22/" . $user,
        "cr-login.cr.intel.com" , "/usr/users/home1/" . $user,
        "ch-login.ch.intel.com" , "/nfs/ch/disks/ch_home_disk001/" . $user,
        "fm-login.fm.intel.com" , "/nfs/fm/disks/fm_home_home2/" . $user,
        "igk-login.igk.intel.com" , "/user/" . $user,
        "png-login.png.intel.com" , "/nfs/png/home/" . $user,
        "inn-login.inn.intel.com" , "/users/" . $user,
        "ims-login.ims.intel.com" , "/nfs/site/home/" . $user,
        "ins-login.ins.intel.com" , "/nfs/site/home/" . $user,
        "nc-login.nc.intel.com" , "/nfs/nc/home/" . $user,
        "tm-login.tm.intel.com" , "/nfs/tm/home/" . $user,
        "upc-login.upc.intel.com" , "/users/" . $user,
        "tlsutil001.tl.intel.com" , "/nfs/tl/home/" . $user,
        "irsutil003.ir.intel.com" , "/nfs/iir/home/" . $user,
        "iul-login.iul.intel.com" , "/users/" . $user,
        "bwsutil001.ibw.intel.com" , "/nfs/ibw/home/" . $user,
        "swsutil001.isw.intel.com" , "/users/" . $user,
        "kavutil001.ka.intel.com" , "/nfs/ka/home/" . $user,
        "hd-login.hd.intel.com" ,"/eng/eng21/" . $user,
        "iind-login.iind.intel.com" , "/nfs/iind/home/" . $user,
        "so-login.so.intel.com" , "/nfs/site/home/" . $user,
        "an-login.an.intel.com" , "/nfs/an/disks/an_home_disk013/" . $user,
        "cl-login.cl.intel.com" , "/nfs/site/home/" . $user,
        "sc-login.sc.intel.com" , "/nfs/site/home/" . $user,
        "fc-login.fc.intel.com" , "/nfs/site/disks/fc_home_disk004/" . $user,
        "ts-login.ts.intel.com" , "/nfs/site/home/" . $user,
        "dp-login.dp.intel.com" , "/nfs/dp/disks/users_1/users/" . $user,
        "pdx-login.pdx.intel.com" , "/nfs/pdx/home/" . $user,
        "musxcfengine01.imu.intel.com" , "/nfs/pdx/home/" . $user,
    );


    my $self = {

        "localhome" => $homedir . "/" . $user,
        "paths" => \%paths, 
    };

    bless( $self , $class );

    return $self;
}


sub getHome
{
    my $self = shift;

    return $self->{ localhome };
}


sub getHomes
{
    my $self = shift;

    return $self->{ paths };
}

1;
