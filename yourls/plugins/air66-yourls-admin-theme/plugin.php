<?php
/*
Plugin Name: Air 66 Design Ltd Theme
Plugin URI: https://air66design.com
Description: This plugin is a responsive design restyle of the YOURLS admin 
Version: 1.0
Author: David Robinson
Author URI: https://air66design.com
*/

// No direct call
if( !defined( 'YOURLS_ABSPATH' ) ) die();


//add css styles to theme
yourls_add_action( 'html_head', 'a66_add_css_styles' );

function a66_add_css_styles() {
	$url = yourls_plugin_url( __DIR__ );
	echo <<<HEAD
			<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0" />
			<link rel="stylesheet" href="$url/dist/style.css">
			<script src="$url/dist/main.js"></script>
HEAD;
}





