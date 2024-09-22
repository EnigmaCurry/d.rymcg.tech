<?php
/*
Plugin Name: Redirect Index
Plugin URI: https://github.com/tomslominski/yourls-redirect-index
Description: Redirect the base directory of YOURLS to a user selected link
Version: 1.1
Author: Tom Slominski
Author URI: http://tomslominski.net/
*/

// No direct calls
if( !defined( 'YOURLS_ABSPATH' ) ) die();

// Register plugin admin page and load translations
yourls_add_action( 'plugins_loaded', 'redirindex_init' );
function redirindex_init() {
    yourls_register_plugin_page( 'redirindex', yourls__( 'Redirect Index', 'redirindex' ), 'redirindex_admin' );
    yourls_load_custom_textdomain( 'redirindex', dirname( __FILE__ ) . '/translations' );
}

// The function that will draw the admin page
function redirindex_admin() {
	if( isset( $_POST['action'] ) && $_POST['action'] == 'redirindex' ) {
		redirindex_admin_save(); // If form data has been sent
	} else {
		redirindex_admin_display(); // If no form data has been sent
	}
}

// If no form data has been sent
function redirindex_admin_display( $message = false, $message_type = false ) {
	$nonce = yourls_create_nonce('redirindex');

	// Bring up the current URL from the database
	$current_url = yourls_get_option( 'redirindex_url' );

	// Build strings
	if( $message ) {
		$message = "<p class=\"message $message_type\">$message</p>";
	} else {
		$message = '';
	}
	
	// Echo the page content
	?>
		<style>
			.full-width {
				width: 100%;
			}
		</style>
	
		<main role="main" class="sub_wrap">
			<h2><?php yourls_e( 'Redirect Index', 'redirindex' ); ?></h2>
			<?php echo $message; ?>
	
			<p><?php yourls_e( 'Enter a URL to which the index page will redirect:', 'redirindex' ); ?></p>
			<form method="post">
				<input type="hidden" name="action" value="redirindex" />
				<input type="hidden" name="nonce" value="<?php echo $nonce; ?>" />
	
				<p><input type="url" name="redir_url" value="<?php echo $current_url; ?>" class="text full-width" /></p>
				<p><input type="submit" value="<?php echo yourls_e( 'Save', 'redirindex' ); ?>" class="button primary" /></p>
			</form>
	
			<p><?php
				if( !file_exists( YOURLS_ABSPATH . '/index.php' ) ) {
					yourls_e( 'Have you copied the index.php file into your YOURLS base directory?', 'redirindex' );
				}
			?></p>
		</main>
	<?php
}

// If form data has been sent
function redirindex_admin_save() {
	yourls_verify_nonce( 'redirindex' );

	$new_url = yourls_sanitize_url( $_POST['redir_url'] );

	if( $new_url == yourls_get_option( 'redirindex_url' ) ) {
		$message = sprintf( yourls__( 'The URL is the same as what you tried to change it to, so it has been kept. <a href="%1$s">Check out your redirect!</a>', 'redirindex' ), YOURLS_SITE );
		redirindex_admin_display( $message, 'error' );
	} elseif( yourls_update_option( 'redirindex_url', $new_url ) ) {
		$message = sprintf( yourls__( 'URL saved successfully. <a href="%1$s">Check out your new redirect!</a>', 'redirindex' ), YOURLS_SITE );
		redirindex_admin_display( $message, 'success' );
	} else {
		$message = yourls__( 'Something went wrong and the URL could not be saved. Please try again.', 'redirindex' );
		redirindex_admin_display( $message, 'error' );
	}
}
?>
