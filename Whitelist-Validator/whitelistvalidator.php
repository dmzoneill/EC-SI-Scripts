<?php

class WhiteListValidator
{
	private $inputfile = "/srv/www/htdocs/in.txt";
	private $outputfile = "/srv/www/htdocs/out.txt";
	private $input = null;
	private $output = null;
	private $rules = array();
	private $results = array();
	
	public function __construct() {}
	
	private function readfile()
	{
		$this->debug( "Reading output file" , 3 );
		$this->input = file( $this->inputfile );
	}
	
	private function writefile()
	{
		$this->debug( "Writing output file" , 3 );
		$lines = array();
				
		foreach( $this->results as $rule )
		{
			if( $rule[0] == "127.0.0.1" )
			{
				continue;
			}
			
			$line = implode( "#" , $rule );
			$lines[] = $line;
		}
		
		file_put_contents( $this->outputfile , implode( "\n" , $lines ) );
		shell_exec( "chmod 666 " . $this->outputfile );
	}

	public function validate()
	{
		$this->debug( "Analyzing input rules" , 3 );
		$this->readfile();
		$this->prepare();
		
		$this->debug( count( $this->rules ) . " to be validated" , 3 );
		$rulescount = count( $this->rules );
		$rulescounter = 0;
		$format = "[%4s/$rulescount] %-9s %-15s %-4s";
		
		foreach( $this->rules as $rule )
		{
			$rulescounter++;
			
			$host = $rule[ 0 ];
			$port = $rule[ 1 ];
			$line = $rule[ 2 ];
						
			$trans_port = explode( ":" , $port );
			
			if( $trans_port[ 1 ]  == "80" || $trans_port[ 1 ] == "8080" || $trans_port[ 1 ] == "443" )
			{
				$scanline = "wget $host -T 2 -t 1 -O /dev/null 2>&1 | grep \"200 OK\" | awk '{print \$6}'";
				$scan = trim( shell_exec( $scanline ) );
				
				if( $scan == "200" )
				{
					$this->debug( sprintf( $format , $rulescounter , "open" , $host , $port ) , 3 );
					$this->results[] = array( $host , $port , $line , 1 );
				}
				else
				{
					$this->debug( sprintf( $format , $rulescounter , "filtered" , $host , $port ) , 3 );
					$this->results[] = array( $host , $port , $line , 2 );
				}
			}
			else
			{
				if( $trans_port[ 0 ] == "udp" )
				{
					$scanline = "/usr/local/bin/nmap -sU -p " . $trans_port[ 1 ] . " -PN $host | grep ^" . $trans_port[ 1 ] . " | awk '{print \$2}'";
				}
				else
				{
					$scanline = "/usr/local/bin/nmap -p " . $trans_port[ 1 ] . " -PN $host | grep ^" . $trans_port[ 1 ] . " | awk '{print \$2}'";
				}
				
				$scan = trim( shell_exec( $scanline ) );
				
				if( $scan == "open" ) 
				{
					$this->debug( sprintf( $format, $rulescounter , $scan , $host , $port ) , 3 );
					$this->results[] = array( $host , $port , $line , 1 );
				}
				else if( $scan == "filtered" )
				{
					$this->debug( sprintf( $format , $rulescounter , $scan , $host , $port ) , 3 );
					$this->results[] = array( $host , $port , $line , 2 );
				}
				else if( $scan == "closed" )
				{
					$this->debug( sprintf( $format , $rulescounter , $scan , $host , $port ) , 3 );
					$this->results[] = array( $host , $port , $line , 3 );
				}
				else if( $scan == "open|filtered" )
				{
					$this->debug( sprintf( $format , $rulescounter , $scan , $host , $port ) , 3 );
					$this->results[] = array( $host , $port , $line , 4 );
				}
				else
				{
					if( $trans_port[ 0 ] == "udp" )
					{
						$scanline = "/usr/local/bin/nmap -sU -p " . $trans_port[ 1 ] . " -PN $host";
					}
					else
					{
						$scanline = "/usr/local/bin/nmap -p " . $trans_port[ 1 ] . " -PN $host";
					}
					
					$scan = trim( shell_exec( $scanline ) );
					print $scanline . "\n" . $scan;
				}
			}
		}
		
		$this->writefile();
	}
	
	private function prepare()
	{
		$this->debug( "Begining rules expansion" , 3 );
		
		foreach( $this->input as $line )
		{
			$parts = explode( "|" , $line );
			$host = trim( $parts[ 0 ] );
			$port = trim(  $parts[ 1 ] );
			$this->rules = array_merge( $this->expand( $host , $port , $line ) , $this->rules );
			$this->debug( $this->sprint_r( $this->rules ) , 5 );
		}
	}
	
	private function expand( $host , $port , $line )
	{
		$expanded = array();
		$hosts = array();
		$ports = array();
		
		$hosts = strstr( $host , "," ) ? explode( "," , $host ) : array( $host );
		$ports = strstr( $port , "," ) ? explode( "," , $port ) : array( $port );
			
		foreach( $hosts as $host )
		{
			foreach( $ports as $port )
			{
				if( !strstr( $port , ":" ) )
				{
					$expanded[] = array( trim( $host ) , "udp:" . trim( $port ) , trim( $line ) , -1 );
					$expanded[] = array( trim( $host ) , "tcp:" . trim( $port ) , trim( $line ) , -1 );
				}
				else
				{
					$expanded[] = array( trim( $host ) , trim( $port ) , trim( $line ) , -1 );
				}
			}
		}
		
		$expandedRoundrobins = array();
		
		foreach( $expanded as $entry )
		{
			$host = $entry[ 0 ];
			$port = $entry[ 1 ];
			$line = $entry[ 2 ];
			
			$validip = filter_var( $host , FILTER_VALIDATE_IP );
			
			if( $validip == false )
			{
				$nslookup = shell_exec( "nslookup $host" );
				$lines = explode( "\n" , $nslookup );
				array_shift( $lines );
				array_shift( $lines );
				$nslookup = implode( "\n" , $lines );
				
				if( preg_match_all( "/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/" , $nslookup , $matches ) > 0 )
				{
					$ips = $matches[ 0 ];
					
					foreach( $ips as $ip )
					{
						$expandedRoundrobins[] = array( $ip , $port , $line , -1 );
					}
				}
			}
			else
			{
				$expandedRoundrobins[] = array( $host , $port , $line , -1 );
			}
		}
		
		return $expandedRoundrobins;
	}
	
	private function sprint_r( $var ) 
	{
		ob_start();
		print_r( $var );
		$output = ob_get_contents();
		ob_end_clean();
		return $output;
	}
	
	private function debug( $string , $level )
	{
		if( $level < 4 )
		{
			print $string . "\n";
		}
	}
}


$wlv = new WhiteListValidator();
$wlv->validate();
