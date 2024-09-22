<?php
/*
Plugin Name: YOURLS Favicon
Plugin URI: https://github.com/yourls/yourls-favicon
Description: Displays a fancy YOURLS favicon in all flavors (Chrome, Safari, Android...)
Version: 1.0
Author: Ozh
Author URI: https://ozh.org/
*/

// No direct call
if( !defined( 'YOURLS_ABSPATH' ) ) die();

yourls_add_filter('shunt_html_favicon', 'yourls_plugin_favicon');

function yourls_plugin_favicon() {
    $url = yourls_plugin_url(__DIR__).'/assets';
    $ver = YOURLS_VERSION;

    echo <<<HTML

    <link rel="apple-touch-icon" sizes="180x180" href="$url/apple-touch-icon.png?v=$ver">
    <link rel="icon" type="image/png" sizes="32x32" href="$url/favicon-32x32.png?v=$ver">
    <link rel="icon" type="image/png" sizes="16x16" href="$url/favicon-16x16.png?v=$ver">
    <link rel="manifest" href="$url/site.webmanifest?v=$ver">
    <link rel="mask-icon" href="$url/safari-pinned-tab.svg?v=$ver" color="#5bbad5">
    <link rel="shortcut icon" href="$url/favicon.ico?v=$ver">
    <meta name="msapplication-TileColor" content="#4ea3c5">
    <meta name="msapplication-TileImage" content="$url/mstile-144x144.png">
    <meta name="msapplication-config" content="$url/browserconfig.xml?v=$ver">
    <meta name="theme-color" content="#4ea3c5">

HTML;

    return true;
}
