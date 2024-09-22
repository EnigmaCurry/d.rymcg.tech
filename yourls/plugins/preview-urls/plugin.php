<?php
/*
Plugin Name: Preview URL
Plugin URI: https://yourls.org/
Description: Preview URLs before you're redirected there
Version: 1.0
Author: Ozh
Author URI: https://ozh.org/
*/

// EDIT THIS

// Character to add to a short URL to trigger the preview interruption
define( 'OZH_PREVIEW_CHAR', '~' );

// DO NO EDIT FURTHER

// Handle failed loader request and check if there's a ~
yourls_add_action( 'loader_failed', 'ozh_preview_loader_failed' );
function ozh_preview_loader_failed( $args ) {
        $request = $args[0];
        $pattern = yourls_make_regexp_pattern( yourls_get_shorturl_charset() );
        if( preg_match( "@^([$pattern]+)".OZH_PREVIEW_CHAR."$@", $request, $matches ) ) {
                $keyword   = isset( $matches[1] ) ? $matches[1] : '';
                $keyword = yourls_sanitize_keyword( $keyword );
                ozh_preview_show( $keyword );
                die();
        }
}

// Show the preview screen for a short URL
function ozh_preview_show( $keyword ) {
        require_once( YOURLS_INC.'/functions-html.php' );

        yourls_html_head( 'preview', 'Short URL preview' );
        yourls_html_logo();

        $title = yourls_get_keyword_title( $keyword );
        $url   = yourls_get_keyword_longurl( $keyword );
        $base  = YOURLS_SITE;
        $char  = OZH_PREVIEW_CHAR;

        echo <<<HTML
        <h2>Link Preview</h2>
        <p>You requested the short URL <strong><a href="$base/$keyword">$base/$keyword</a></strong></p>
        <p>This short URL points to:</p>
        <ul>
        <li>Long URL: <strong><a href="$base/$keyword">$url</a></strong></li>
        <li>Page title: <strong>$title</strong></li>
        </ul>
        <p>If you still want to visit this link, please <strong><a href="$base/$keyword">click here</a></strong>.</p>

        <p>Thank you for using our shortening service.</p>
HTML;

        yourls_html_footer();
}
