<?php
// XXX Uncomment these lines if you run into memory limit failures, or if you want to limit the time the script runs
// ini_set('max_execution_time', 3000);
// ini_set('memory_limit','512M');

// Deny http access
if( isset ( $_SERVER['HTTP_HOST'] ) )
	die( "Access denied" );

define('EXPIRY_CLI', true);

// load yourls
require_once( dirname( __FILE__ ) . '/../../../../includes/load-yourls.php' );

// load options 
$options = getopt( null , [ "signature::" , "scope::" ]);

// require options
if (count($options) == 0)
	die( "\nNeither authentication signature nor scope found, please try again.\n" );
// require sig auth option
if ( !array_key_exists('signature', $options ) )
	die( "\nNo authentication signature found, please try again.\n" );
// require valid signature
if ( !expiry_prune_inc_auth( $options['signature'] ) )
	die( "\nAuthentication failed, please try again.\n" );

// set scope
if ( array_key_exists( 'scope', $options ) )
	$scope = $options['scope'];
else
	$scope = 'expired';

switch( $scope ) {

	case 'expired':
		
		if( expiry_db_flush( $scope ) )
			echo "\nLinks have been pruned\n";
		else
			echo "\nError: could not prune expiry, not sure why\n";

		break;

	case 'scrub':
		
		if( expiry_db_flush( $scope ) )
			echo "\nExpirations have been stripped from all links\n";
		else
			echo "\nError: could not prune expiry, not sure why\n";

		break;

	case 'killall':

		if( expiry_db_flush( $scope ) )
			echo "\nAll perishable links have been pruned.\n";
		else
			echo "\nError: could not prune expiry, not sure why\n";

		break;
}
