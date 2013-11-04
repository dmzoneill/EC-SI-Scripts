<html>
<head>
<style>
body,table,tr,td,textarea
{
	font-size:9pt;
	font-family:arial;
}

th
{
	text-align:left;
}
</style>
</head>
<body>

<?php
if( isset( $_POST[ 'rules' ] ) ) 
{
	print "Sucessfully Edited<br>";
	file_put_contents( "in.txt" , $_POST[ 'rules' ] );
}

if( isset( $_GET[ 'edit' ] ) )
{
	$rules = file_get_contents( "in.txt" );

	print "Editing Rules:<br>Format: host[,host] | [transport:]port,[[transport:]port]<br>";
	print "<form action='index.php' method='post'>";
	print "<textarea cols=180 rows=40 wrap=off name='rules'>$rules</textarea><br><br>";
	print "<input type='submit' value='Apply'></form>";
}
else
{
	$lines = array_reverse( file( "out.txt" ) ); 

	echo "[ <a href='index.php?edit=true'>edit scan</a> ] Scan finished: " . date ( "D H:i:s.", filemtime( "out.txt" ) );

	print "<br><table border=0 cellspacing=0 cellpadding=1>";

	$last = "";

	foreach( $lines as $line )
	{
		$aline = explode( "#" , $line );
		$bgcolor = ( trim( $aline[ 3 ] ) == "2" ) ? "#BB0000" : "#00BB00";
		$bgcolor = ( trim( $aline[ 3 ] ) == "4" ) ? "#FF6600" : $bgcolor;
		$status = ( trim( $aline[ 3 ] ) == "2" ) ? "Filtered" : "Open";
		$status = ( trim( $aline[ 3 ] ) == "4" ) ? "Filtered/Open" : $status;
	

		if( $last != $aline[ 2 ] )
		{
			print "<tr><td colspan='4'>";
			$parts = explode( "|" , $aline[ 2 ] );
			print "<hr><b>Destinations:</b> " . $parts[ 0 ] . "<br>";
			print "<b>Ports:</b> " . $parts[ 1 ] . "<br><hr>";
			print "</td></tr>";
			$last = $aline[ 2 ];
			print "<tr><th></th><th>Status</th><th>Destination</th><th>Port</th></tr>";
		}

		print "<tr><td width='50'></td><td width='90'><font color='$bgcolor'>$status</font></td><td width='100'>" . $aline[0] ."</td><td>" . $aline[1] . "</td></tr>";
	}

	print "</table>";
}

?>
</body>
</html>
