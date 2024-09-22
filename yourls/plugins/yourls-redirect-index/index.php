<?php
/**
 * index.php from Redirect Index
 * https://github.com/tomslominski/yourls-redirect-index
 *
 * Make sure to copy this into the base directory of your YOURLS installation!
 */

// Start YOURLS engine
require_once( dirname(__FILE__) . '/includes/load-yourls.php' );

// Write URL to variable
$redir_url = yourls_get_option( 'redirindex_url' );

// Perform the redirect
if( ( yourls_is_active_plugin( 'yourls-redirect-index/plugin.php' ) || yourls_is_active_plugin( 'redirect-index/plugin.php' ) ) && !empty( $redir_url ) ) {
	Header( "Location: $redir_url" );
} else {
	echo '<h2>' . yourls__( 'YOURLS Redirect Index', 'redirindex' ) . '</h2>';
	echo '<p>' . yourls__( 'Have you enabled the plugin and set the redirect URL in the YOURLS admin panel? If you\'re having trouble, check out the <a href="https://github.com/tomslominski/yourls-redirect-index">project page</a>.', 'redirindex' ) . '</p>';
}

?>
