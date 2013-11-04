use strict;
use warnings;
use WWW::Curl::Easy;
use SOAP::Lite;
use File::Slurp;
use MIME::Lite;
use Net::SMTP;
use Time::HiRes qw( usleep );
use IO::Prompt;
use Cwd qw(abs_path);


#
# Settings
##################################################################################################################
    
my $central = "ipamdb.intel.com";
my $web = "ipam.intel.com";
my $zonename = "ir.intel.com.";
my $mailHost = 'mailhost.ir.intel.com';
my $from = 'sie.it@intel.com';

my @subnets = ( "10.237.217" , "10.243.17" , "10.243.18" , "10.237.216" , "10.237.214" , "10.237.213" , "10.237.212" , "10.243.22" , "10.243.23" );
my %recipients = 	(
						"10.237.217" , 'david.m.oneill@intel.com',
						"10.243.17" , 'david.m.oneill@intel.com',
						"10.243.18" , 'david.m.oneill@intel.com',
                        "10.237.216" , 'david.m.oneill@intel.com',
                        "10.237.214" , 'david.m.oneill@intel.com',
						"10.237.213" , 'david.m.oneill@intel.com',
						"10.237.212" , 'david.m.oneill@intel.com',
						"10.243.22" , 'david.m.oneill@intel.com',
						"10.243.23" , 'david.m.oneill@intel.com'
					);
my @reportUp = ();
my @reportDown = ();
my @reportCnameUp = ();
my @reportCnameDown = ();
my @reportRpUp = ();
my @reportRpDown = ();
my @reportTxtUp = ();
my @reportTxtDown = ();


#
# Request Ipam Credentials
##################################################################################################################
my $domain = prompt( 'DOMAIN : ' );
my $idsid = prompt( 'IDSID : ' );
my $username = "$domain\\$idsid";
my $pw = prompt 'Password : ',  -echo => '*';
my $password = "" . $pw;


#
# Sub Routines
##################################################################################################################

sub SOAP::Serializer::as_SortOrder 
{
	my $self = shift;
	my( $value , $name , $type , $attr ) = @_;
	$attr->{ 'xsi:type' } = $type;
	return [ $name , $attr , $value ];
}

sub SOAP::Serializer::as_ObjRef 
{
	my $self = shift;
	my( $value , $name , $type , $attr ) = @_;
	$attr->{ 'xsi:type' } = $type;
	return [ $name , $attr , $value ];
}

sub SOAP::Serializer::as_ObjectType 
{
	my $self = shift;
	my( $value , $name , $type , $attr ) = @_;
	$attr->{ 'xsi:type' } = $type;
	return [ $name , $attr , $value ];
}

sub SOAP::Serializer::as_DNSRecordType 
{
	my $self = shift;
	my( $value , $name , $type , $attr ) = @_;
	$attr->{ 'xsi:type' } = $type;
	return [ $name , $attr , $value ];
}

sub report
{
	use vars qw( @reportUp @reportdown $username %recipients $mailHost $from @reportCnameUp @reportCnameDown @reportRpUp @reportRpDown @reportTxtUp @reportTxtDown );
		
	my $subnet = shift;
	my $path = abs_path( $0 );
	my $goodhtml = "";
	my $badhtml = "";
	
	my $hostname = `uname -n`;
	chomp( $hostname );	
	my $htmlBody = read_file( 'report.html' );
	
	if( open( FILE , ">" , "$subnet.csv" ) )
	{
		print FILE "\"Validity\",\"M&M ID\",\"Record\",\"Type\",\"Value\",\"Kcdb\",\"Nodes\"\n";
		
		foreach my $record( @reportUp )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = (@{$record}[4] == 1) ? "yes" : "no";
			my $nodes = (@{$record}[5] == 1) ? "yes" : "no";
			$goodhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportCnameUp )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = "";
			my $nodes = "";
			$goodhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportTxtUp )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = "";
			my $nodes = "";
			$goodhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportRpUp )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = "";
			my $nodes = "";
			$goodhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportDown )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = (@{$record}[4] == 1) ? "yes" : "no";
			my $nodes = (@{$record}[5] == 1) ? "yes" : "no";
			$badhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"no\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportCnameDown )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = "";
			my $nodes = "";
			$badhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportTxtDown )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = "";
			my $nodes = "";
			$badhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		foreach my $record( @reportRpDown )
		{
			my $refr = @{$record}[0];
			my $name = @{$record}[1];
			my $type = @{$record}[2];
			my $val = @{$record}[3];
			my $kcdb = "";
			my $nodes = "";
			$badhtml .= "<tr><td>" . $refr . "</td><td>" . $name . "</td><td>" . $type . "</td><td>" . $val . "</td><td>" . $kcdb . "</td><td>" . $nodes . "</td></tr>\n";
			print FILE "\"yes\",\"$refr\",\"$name\",\"$type\",\"$val\",\"$kcdb\",\"$nodes\"\n";
		}
		
		close( FILE );
			
		$path = $hostname . ":" . $path;
		$htmlBody =~ s/R_SUBNET/$subnet/g;
		$htmlBody =~ s/R_BADRECORDS/$badhtml/g;
		$htmlBody =~ s/R_GOODRECORDS/$goodhtml/g;#$html
		$htmlBody =~ s/R_LOCATION/$path/g;
		$htmlBody =~ s/R_USER/$username/g;		
				
		my $lrecipient = $recipients{ "$subnet" };
		
		my $msg = MIME::Lite->new(
			From    => "$from",
			To      => "$lrecipient",
			Cc      => '',
			Subject => "Men & Mice $subnet / Kcdb / Nodes Cross Reference Report",
			Type    => 'multipart/related'
		);

		$msg->attach(
			Type     => 'text/html',
			Data     => qq
						{
							$htmlBody
						},
		);

		$msg->attach(
			Type        => 'image/jpeg',
			Path        => '/home/dmoneil2/scripts/menandmice/intel-small.jpg',
			Id    		=> 'intel-small.jpg',
		);
		
		$msg->attach(
			Type		=>	'text/csv',
			Path		=>	"$subnet.csv",
			Filename	=>	"$subnet.csv",
			Disposition	=>	'attachment'
		);
		
		$msg->send;
		
		my $cleanup = `rm -rvf *.csv`;
	}
}


sub checknodes
{
	my $ip = shift;
	my $nodecmd = "ucat nodes | grep \"". $ip . " \" | awk '{split(\$0,parts,\" \")} END{print parts[1]}' | awk '{split(\$0,parts,\"=\")} END{print parts[2]}'";
	$nodecmd = `$nodecmd`;
	chomp( $nodecmd );
	
	if( $nodecmd !~ /[0-9a-zA-Z]+/ )
	{
		return 0;
	}
	
	return 1;
}


sub checkkcdb
{
	use vars qw( $username $password );

	my $hostname = shift;
	my $fqdn1 = $hostname . ".ir.intel.com";
	my $fqdn2 = $hostname . ".ger.corp.intel.com";
	my $curl;
	my $retcode;
	my $response_body = "";

	$curl = WWW::Curl::Easy->new;   
	$curl->setopt( CURLOPT_USERAGENT , "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; .NET CLR 1.1.4322; .NET4.0C; .NET4.0E; InfoPath.3; Zune 4.7; MS-RTC LM 8)" );
	$curl->setopt( CURLOPT_URL , 'http://kcdb.intel.com/Dashboard/includes/Dashboard.ajax.asp' );
	$curl->setopt( CURLOPT_POST , 1 );
	$curl->setopt( CURLOPT_HTTPAUTH , CURLAUTH_NTLM );
	$curl->setopt( CURLOPT_USERPWD , "$username:$password" );
	$curl->setopt( CURLOPT_POSTFIELDS , "task=getObjList&ObjName=%25" . $fqdn1 );
	$curl->setopt( CURLOPT_WRITEDATA , \$response_body );

	$retcode = $curl->perform;

	if( $retcode == 0 ) 
	{
		my $response_code = $curl->getinfo( CURLINFO_HTTP_CODE );
		chomp( $response_body );
		
		if( $response_body =~ /[0-9]+\|$fqdn1(.*)\[i]\|/ )
		{
			return 1;
		}	
	} 
	else 
	{
		print "An error happened: $retcode " . $curl->strerror($retcode) . " " . $curl->errbuf . "\n";
	}
	

	$curl = WWW::Curl::Easy->new;   
	$curl->setopt( CURLOPT_USERAGENT , "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; .NET CLR 1.1.4322; .NET4.0C; .NET4.0E; InfoPath.3; Zune 4.7; MS-RTC LM 8)" );
	$curl->setopt( CURLOPT_URL , 'http://kcdb.intel.com/Dashboard/includes/Dashboard.ajax.asp' );
	$curl->setopt( CURLOPT_POST , 1 );
	$curl->setopt( CURLOPT_HTTPAUTH , CURLAUTH_NTLM );
	$curl->setopt( CURLOPT_USERPWD , "$username:$password" );
	$curl->setopt( CURLOPT_POSTFIELDS , "task=getObjList&ObjName=%25" . $fqdn2 );
	$curl->setopt( CURLOPT_WRITEDATA , \$response_body );

	$retcode = $curl->perform;

	if( $retcode == 0 ) 
	{
		my $response_code = $curl->getinfo( CURLINFO_HTTP_CODE );
		chomp( $response_body );
		
		if( $response_body =~ /[0-9]+\|$fqdn2(.*)\[i]\|/ )
		{
			return 1;
		}	
	} 
	else 
	{
		print "An error happened: $retcode " . $curl->strerror($retcode) . " " . $curl->errbuf . "\n";
	}

	return 0;
}


my $service = SOAP::Lite->service( 'http://' . $web . '/_mmwebext/mmwebext.dll?wsdl?server=' . $central );
my $sessionid = $service->Login( $central , $username , $password , 0 );

print "Session id : " . $sessionid . "\n"; 

if( $sessionid ne "" )
{
	print "Connected\n";
	my @result = $service->GetDNSZones( $sessionid , "name:\^$zonename\$ type:\^master\$" , 0 , 0 , 'name' , SOAP::Data->type( "SortOrder" => 'Ascending' ) );
	my $totalResults = $result[ -1 ];

	if( $totalResults gt 1 )
	{
		print "More than one zone returned - stop!\n";
		exit( 0 );
	}

	if( $totalResults eq 0 )
	{
		print "Zone with name $zonename not found - stop!\n";
		exit( 0 );
	}
	
	print "Found Zone\n";
	
	my $dnszoneref = $result[ 0 ]->{ 'dnsZone' }->{ 'ref' };
	my @records = $service->GetDNSRecords( $sessionid , SOAP::Data->type( "ObjRef" => $dnszoneref ), '' , 0 , 0 , 0 , 'name' , SOAP::Data->type( "SortOrder" => 'Ascending' ) );

	print "Got Records\n";
	
	$totalResults = $records[ -1 ];
	
	my $counter = 0;
	
	foreach my $subnet( @subnets )
	{
		@reportUp = ();
		@reportDown = ();
		@reportCnameUp = ();
		@reportCnameDown = ();
		@reportRpUp = ();
		@reportRpDown = ();
		@reportTxtUp = ();
		@reportTxtDown = ();
		
		print "Analysing $subnet\n";
		
		# A records
		for( $counter=0; $counter < $totalResults; $counter++ )
		{
			my $r_refr = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'ref' };
			my $r_name = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'name' };
			my $r_type = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'type' };
			my $r_data = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'data' };
						
			if( $r_data =~ m/$subnet/i )
			{
				my $simpleScan = "/usr/bin/nmap -p T:22,139 -R $r_data | grep \"host up\" | wc -l";
				my $scan = `$simpleScan`;
				chomp( $scan );
				
				my $kcdb = checkkcdb( $r_name );
				my $nodes = checknodes( $r_data );
				
				if( $scan eq "1" )
				{
					push( @reportUp , [ $r_refr , $r_name , $r_type , $r_data , $kcdb , $nodes ] );
				}			
				else
				{
					push( @reportDown , [ $r_refr , $r_name , $r_type , $r_data , $kcdb , $nodes ] );
				}
				
				printf( "%20s %25s %3s %18s\n" , $r_refr , $r_name , $r_type , $r_data );
				
				usleep( 100000 );
			}
		}
		
		# RP / TXT Records
		for( $counter=0; $counter < $totalResults; $counter++ )
		{
			my $r_refr = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'ref' };
			my $r_name = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'name' };
			my $r_type = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'type' };
			my $r_data = $records[ 0 ]->{ 'dnsRecord' }[ $counter ]->{ 'data' };
			
			foreach my $record( @reportDown )
			{
				my $name = @{$record}[1];
				my $type = @{$record}[2];
							
				if( $r_name =~ /$name/i && $r_type =~ /RP/i  )
				{
					push( @reportRpDown , [ $r_refr , $r_name , $r_type , $r_data , -1 , -1 ] );
				}
				
				if( $r_name =~ /$name/i && $r_type =~ /TXT/i  )
				{
					push( @reportTxtDown , [ $r_refr , $r_name , $r_type , $r_data , -1 , -1 ] );
				}
				
				if( $r_data =~ /$name/i && $r_type =~ /CNAME/i  )
				{
					push( @reportCnameDown , [ $r_refr , $r_name , $r_type , $r_data , -1 , -1 ] );
				}
			}
			
			foreach my $record( @reportUp )
			{
				my $name = @{$record}[1];
				my $type = @{$record}[2];
							
				if( $r_name =~ /$name/i && $r_type =~ /RP/i  )
				{
					push( @reportRpUp , [ $r_refr , $r_name , $r_type , $r_data , -1 , -1 ] );
				}
				
				if( $r_name =~ /$name/i && $r_type =~ /TXT/i  )
				{
					push( @reportTxtUp , [ $r_refr , $r_name , $r_type , $r_data , -1 , -1 ] );
				}
				
				if( $r_data =~ /$name/i && $r_type =~ /CNAME/i  )
				{
					push( @reportCnameUp , [ $r_refr , $r_name , $r_type , $r_data , -1 , -1 ] );
				}
			}
		}
				
		report( $subnet );
	}
	
	$service->Logout( $sessionid );	
}


