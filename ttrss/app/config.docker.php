<?php

	$snippets = glob(getenv("SCRIPT_ROOT")."/config.d/*.php");

	foreach ($snippets as $snippet) {
		require_once $snippet;
	}


	define('NGINX_XACCEL_PREFIX', '/tt-rss');
