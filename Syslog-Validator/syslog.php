<?php

class SyslogTester
{
	private $facilities = array();
	private $priorities = array();
	private $tests = array();
	
	public function __construct()
	{
		$this->facilities[] = "auth";
		$this->facilities[] = "authpriv";
		$this->facilities[] = "cron";
		$this->facilities[] = "daemon";
		$this->facilities[] = "ftp";
		$this->facilities[] = "kern";
		$this->facilities[] = "lpr";
		$this->facilities[] = "mail";
		$this->facilities[] = "mark";
		$this->facilities[] = "news";
		$this->facilities[] = "security";
		$this->facilities[] = "user";
		$this->facilities[] = "uucp";
		$this->facilities[] = "local0";
		$this->facilities[] = "local1";
		$this->facilities[] = "local2";
		$this->facilities[] = "local3";
		$this->facilities[] = "local4";
		$this->facilities[] = "local5";
		$this->facilities[] = "local6";
		$this->facilities[] = "local7";
		
		$this->priorities[] = "emerg";
		$this->priorities[] = "alert";
		$this->priorities[] = "crit";
		$this->priorities[] = "err";
		$this->priorities[] = "warning";
		$this->priorities[] = "notice";
		$this->priorities[] = "info";
		$this->priorities[] = "none";
	}
	
	
	private function ReadConf( $config )
	{
		$lines = file( $config );
		
		foreach( $lines as $line )
		{
			if( trim( $line ) == "" )
			{	
				continue;
			}
			else if( substr( $line , 0 ,1 ) == "#" )
			{
				continue;
			}
			else 
			{
				$this->ParseLogLine( trim ( $line ) );
			}
		}
	}
	
	
	private function ParseLogLine( $line )
	{
		$lineparts  = preg_split( "/\s+/" , $line );
		
		# file logging section
		if( strstr( $lineparts[ count( $lineparts ) - 1 ] , "/var/log" ) )
		{
			$logfile = substr( $lineparts[ count( $lineparts ) - 1 ] , 1 );
			
			if( strstr( $lineparts[ 0 ] , ";" ) )
			{
				$bits = explode( ";" , $lineparts[ 0 ] );
				
				foreach( $bits as $bit )
				{
					$this->tests[] = array( $bit , $logfile );
				}
			}
			else if( strstr( $lineparts[ 0 ] , "," ) )
			{
				$parts = explode( "." , $lineparts[ 0 ] );
				$bits = explode( "," , $parts[ 0 ] );
				
				foreach( $bits as $bit )
				{
					$this->tests[] = array( $bit . "." . $parts[ 1 ] , $logfile );
				}
			}
			else
			{
				$this->tests[] = array( $lineparts[ 0 ] , $logfile );
			}
		}
	}
	
	
	private function GetRand( $length = 20 ) 
	{
		$chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
		$count = strlen( $chars );

		for( $i = 0, $result = ''; $i < $length; $i++ ) 
		{
			$index = rand( 0 , $count - 1 );
			$result .= substr( $chars, $index, 1 );
		}

		return $result;
	}
	
	
	private function termcolored( $text , $color=31 )
	{
		$perl = "perl -e \"print chr(27) . '[1;" . $color . "m$text' . chr(27) . '[0m';\"";
		echo exec( $perl );
	}
	
	
	private function Validate( $facility , $priority , $message , $logfile )
	{		
		$tail = shell_exec( "/usr/bin/tail -n 10 $logfile" );
		$contains = false;
		
		if( stristr( $tail , $message ) )
		{
			$contains = true;
		}
		
		if( $contains && $priority == "none" )
		{
			$this->termcolored( "In/Valid" , 34 );
			print " Assertion : ";
			$this->termcolored( "     $facility.$priority" , 33 );
			print "    : found $message in $logfile\n";
		}
		
		if( !$contains && $priority != "none" )
		{
			$this->termcolored( "Invalid" , 31 );
			print " Assertion : ";
			$this->termcolored( "     $facility.$priority" , 33 );
			print "    : $message not found in $logfile\n";
		}
		
		if( $contains && $priority != "none" )
		{
			$this->termcolored( "Valid" , 32 );
			print " Assertion   : ";
			$this->termcolored( "     $facility.$priority" , 33 );
			print "    : found $message in $logfile\n";
		}
	}
	
	
	private function AssertTest( $test )
	{
		$me = " - syslog debugging contact dmoneil2";
		$logfile = $test[ 1 ];
		$dest = explode( "." , $test[ 0 ] );
		
		if( $dest[ 0 ] == "*" )
		{
			foreach( $this->facilities as $facility )
			{
				$message = $this->GetRand();
				$message1 = $facility . "." . $dest[ 1 ] . " - " . $message . " " . $me;
				$command = "/bin/logger -p $facility." . $dest[ 1 ] . " '$message1'";
				shell_exec( $command );
				sleep( 2 );
				$this->Validate( $facility , $dest[ 1 ] , $message , $logfile );
			}
		}
		else if( $dest[ 1 ] == "*" )
		{
			foreach( $this->priorities as $priority )
			{
				$message = $this->GetRand();
				$message1 = $dest[ 0 ] . "." . $priority . " - " . $message . " " . $me;
				$command = "/bin/logger -p " . $dest[ 0 ] . "." . $priority . " '$message1'";
				shell_exec( $command );
				sleep( 2 );
				$this->Validate( $dest[ 0 ] , $priority , $message , $logfile );
			}
		}
		else
		{
			$message = $this->GetRand();
			$message1 = $test[ 0 ] . " - " . $message . " " . $me;
			$command = "/bin/logger -p " . $test[ 0 ] . " '$message1'";
			shell_exec( $command );
			sleep( 2 );
			$this->Validate( $dest[ 0 ] , $dest[ 1 ] , $message , $logfile );
		}	
	}

	
	public function Test( $config = "/etc/rsyslog.conf" )
	{
		$this->ReadConf( $config );
	
		foreach( $this->tests as $test )
		{
			$this->AssertTest( $test );
		}
	}
}


$SyslogTester = new SyslogTester();
$SyslogTester->Test();

