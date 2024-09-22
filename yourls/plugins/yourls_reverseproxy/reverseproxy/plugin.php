<?php
/*
Plugin Name: ReverseProxy
Plugin URI: https://github.com/Diftraku/yourls_cloudflare/
Description: Fixes incoming IPs to use the client IP from reverse proxies
Version: 2.1
Author: Diftraku
*/

// Block direct access to the plugin
if( !defined( 'YOURLS_ABSPATH' ) ) die();

// Add a filter to get_IP for the real IP instead of the reverse proxy
yourls_add_filter( 'get_IP', 'reverseproxy_get_ip');
function reverseproxy_get_ip( $ip ) {
	if ( isset( $_SERVER['HTTP_CF_CONNECTING_IP'] ) ) {
		$ip = $_SERVER['HTTP_CF_CONNECTING_IP'];
	} elseif ( isset( $_SERVER['HTTP_X_FORWARDED_FOR'] ) ) {
		$ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
	} elseif ( isset ( $_SERVER['HTTP_X_REAL_IP'] ) ) {
		$ip = $_SERVER['HTTP_X_REAL_IP'];
	}
	return yourls_sanitize_ip( $ip );
}
