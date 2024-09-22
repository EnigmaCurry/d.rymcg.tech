<?php
/*
Plugin Name: Expiry
Plugin URI: https://github.com/joshp23/YOURLS-Expiry
Description: Will set expiration conditions on your links (or not)
Version: 2.4.1
Author: Josh Panter
Author URI: https://unfettered.net
*/
// No direct call
if( !defined( 'YOURLS_ABSPATH' ) ) die();
/*
 *
 * EARLY LOADER FUNCTIONS
 *
 *
*/
yourls_add_action( 'plugins_loaded', function () {

	// Register admin forms
	yourls_register_plugin_page( 'expiry', 'Expiry', 'expiry_do_page' );
	
	// Is authMgrPlus active?
	if( yourls_is_active_plugin( 'authMgrPlus/plugin.php' ) ) {
		
		yourls_add_filter( 'amp_action_capability_map', function( $var ) {
			$var += ['expiry-stats' => ampCap::ViewStats]; 
			return $var; } );
			
		yourls_add_filter( 'amp_button_capability_map', function( $var ) { 
			$var += ['expiry' => ampCap::DeleteURL];
			return $var; } );
			
		yourls_add_filter( 'amp_restricted_buttons', 	function( $var ) { 
			$var += ['expiry'];
			return $var; } );
	}

	// Expiry-Change-Error-MSG
	if( !yourls_is_active_plugin('change-error-messages/plugin.php') ) {
		// If the keyword exists, display the long URL in the error message
		yourls_add_filter( 'add_new_link', function ( $return, $url, $keyword, $title  ) {
			if ( isset( $return['code'] ) ) {
				if ( $return['code'] === 'error:keyword' ){
					$long_url = yourls_get_keyword_longurl( $keyword );
					if ($long_url){
						$return['message']	= 'The keyword "' . $keyword . '" already exists for: ' . $long_url;
					} elseif ( yourls_keyword_is_reserved( $keyword ) ){
									$return['message']	= "The keyword '" . $keyword . "' is reserved";
					}
				}
				elseif ( $return['code'] === 'error:url' ){
					if ($url_exists = yourls_long_url_exists( $url )){
						$keyword = $url_exists->keyword;
						$return['status']   = 'success';
						$return['message']	= 'This URL already has a short link: ' . YOURLS_SITE .'/'. $keyword;
						$return['title']    = $url_exists->title;
						$return['shorturl'] = YOURLS_SITE .'/'. $keyword;
					}
				}
			}
			return yourls_apply_filter( 'after_custom_error_message', $return, $url, $keyword, $title );
		});
	}
});
/*
 *
 * ADMIN PAGE
 *
 *
*/
// Display page 0.01 - maybe insert some JS and CSS files to head
yourls_add_action( 'html_head', function ($context) {
	if ( $context[0] == 'plugin_page_expiry' ) {
		$home = YOURLS_SITE;
		echo "<link rel=\"stylesheet\" href=\"".$home."/css/infos.css?v=".YOURLS_VERSION."\" type=\"text/css\" media=\"screen\" />\n";
		echo "<script src=\"".$home."/js/infos.js?v=".YOURLS_VERSION."\" type=\"text/javascript\"></script>\n";
	} elseif ($context[0] == 'index') {
		$loc = yourls_plugin_url(dirname(__FILE__));
		$file = dirname( __FILE__ )."/plugin.php";
		$data = yourls_get_plugin_data( $file );
		$v = $data['Version'];
		echo "\n<! --------------------------Expiry Start-------------------------- >\n";
		echo "<script src=\"".$loc."/assets/expiry.js?v=".$v."\" type=\"text/javascript\"></script>\n";
		echo "<link rel=\"stylesheet\" href=\"".$loc."/assets/expiry.css?v=".$v."\" type=\"text/css\" />\n";
		echo "<! --------------------------Expiry END---------------------------- >\n";
	}
});
function expiry_do_page() {

	expiry_update_ops();
	expiry_flush();

	$opt = expiry_config();

	// neccessary values for display
	$globalExp = array("none" => " ", "click" => " ", "clock" => " ");
	switch ($opt[9]) {
		case 'click': $globalExp['click'] = 'selected'; break;
		case 'clock': $globalExp['clock'] = 'selected'; break;
		default:      $globalExp['none']  = 'selected'; break;
	}

	$ageMod = array("min" => " ", "day" => " ", "hour" => " ");
	switch ($opt[7]) {
		case 'min':  $ageMod['min']  = 'selected'; break;
		case 'hour': $ageMod['hour'] = 'selected'; break;
		default:     $ageMod['day']  = 'selected'; break;
	}

	$intercept = array("simple" => " ", "custome" => " ", "template" => " ");
	switch ($opt[0]) {
		case 'template': $intercept['template'] = 'selected'; break;
		case 'custome': $intercept['custome'] = 'selected'; break;
		default:      $intercept['simple']  = 'selected'; break;
	}

	$ciVisChk = ( $opt[0] !== 'custome' ? 'none' : 'inline' );

	$unique = ( YOURLS_UNIQUE_URLS == true ) ? ' disabled="disabled" <p><strong>Notice:</strong> <code>YOURLS_UNIQUE_URLS</code> is set to <code>true</code>. This value must be set to <code>false</code> to use this function.</p>' : ' > Use a global post-expiration URL?';
	
	if( $opt[5] == 'false' ) {
		$gpxVisChk = 'none';
		$gpxChk = null;
	} else {
		$gpxVisChk = 'inline';
		$gpxChk = 'checked';
	}
	
	$expChk = ( $opt[3] == 'true' ? 'checked' : null );
	$tblChk = ( $opt[2] == 'true' ? 'checked' : null );

	// Create nonce
	$nonce = yourls_create_nonce( 'expiry' );
	
	// Misc for cron example pre-formatting
	$sig	= yourls_auth_signature();
	$site   = YOURLS_SITE;
	$cronEG   =  rawurlencode('<html><body><pre>0 * * * * wget -O - -q -t 1 <strong>'.$site.'</strong>/yourls-api.php?signature=<strong>'.$sig.'</strong>&format=simple&action=prune&scope=expired >/dev/null 2>&1</pre></body></html>');

echo <<<HTML
	<div id="wrap">
		<div id="tabs">

			<div class="wrap_unfloat">
				<ul id="headers" class="toggle_display stat_tab">
					<li class="selected"><a href="#stat_tab_config"><h2>Config</h2></a></li>
					<li><a href="#stat_tab_exp_list"><h2>Expiry List</h2></a></li>
					<li><a href="#stat_tab_prune"><h2>Prune</h2></a></li>
					<li><a href="#stat_tab_api"><h2>API</h2></a></li>
				</ul>
			</div>

			<div id="stat_tab_config" class="tab">

				<form method="post">
					<br>
					<h3>Default Expiry Type</h3>

					<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<select name="expiry_global_expiry" size="1" >
							<option value="click" {$globalExp['click']}>Click Counter</option>
							<option value="clock" {$globalExp['clock']}>Timer</option>
							<option value="none" {$globalExp['none']}>None</option>
						</select>
						<p>Set this if you want a global expiration condition for ALL new links.</p>
						<p>For example, you can make it so that every new link will expire in 3 days unless otherwise specified. Leave to 'none' for standard YOURLS behavior.</p>
					</div>
					<br>
					<h3>Default Click Counter Value</h3>
					
					<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<input type="hidden" name="expiry_default_click" value="50">
	  					<input type="number" name="expiry_default_click" min="1" max="99999" value=$opt[8]><br>

						<p>If the expiry type is set to 'click' and no 'count' value is set, expiry falls back to this value.</p>
					</div>
					<br>
					<h3>Default Countdown Time Span</h3>

					<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<input type="hidden" name="expiry_default_age" value="50">
	  					<input type="number" name="expiry_default_age" min="1" max="100" value=$opt[6]>
						<select name="expiry_default_age_mod" >
							<option value="min" {$ageMod['min']}>Minute(s)</option>
							<option value="hour" {$ageMod['hour']}>Hour(s)</option>
							<option value="day" {$ageMod['day']}>Day(s)</option>
						</select>
						<p>If the expiry type is set to 'clock' with no other conditions set, expiry falls back to this value.</p>
					</div>
					<br>
					<h3>Expiry Intercept Behavior</h3>
					
					<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<select name="expiry_intercept" size="1" >
							<option value="simple" {$intercept['simple']}>YOURLS style</option>
							<option value="template" {$intercept['template']}>Bootstrap Template</option>
							<option value="custome" {$intercept['custome']}>Custome URL</option>
						</select>
						<p>The click that causes a link to expire must be handled, we intercept it. You can choose how to do that here.</p>
					</div>

					<div style="display:$ciVisChk;">
						<br>
						<h3>Custome Intercept Page</h3>

						<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">

							<p><label for="expiry_custom">Enter intercept URL here</label> <input type="text" size=40 id="expiry_custom" name="expiry_custom" value="$opt[1]" /></p>
							<p>Setting the above option without setting this will fall back to default behavior.</p>

						</div>
					</div>
					<br>
					<h3>Global Post-Expiry Option</h3>

					<div class="checkbox" style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<label>
							<input name="expiry_global_post_expire_chk" type="hidden" value="false" />
							<input name="expiry_global_post_expire_chk" type="checkbox" value="true" $gpxChk $unique
						</label>
						<p>Instead of being deleted form the database, expiry short links can be edited to a new url when they expire. You can set a global value for this here.</p>

						<p>An alternative way to acheive this might be to use the <a href="https://diegopeinador.blogspot.com/2013/04/fallback-url-simple-plugin-for-yourls.html" target="_blank">Fallbak-URL</a> plugin. Combined, there is a lot of flexibility.</p>
					</div>

					<div style="display:$gpxVisChk;">
						<br>
						<h3>Global Post Expiry Destination URL</h3>

						<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">

							<p><label for="expiry_custom">Enter intercept URL here</label> <input type="text" size=40 id="expiry_custom" name="expiry_custom" value="$opt[1]" /></p>
							<p>Setting the above option without setting this will fall back to default behavior.</p>

						</div>
					</div>
					
					<br>
					<h3>Expose Expiry Tags</h3>

					<div class="checkbox" style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<label>
							<input name="expiry_expose" type="hidden" value="false" />
							<input name="expiry_expose" type="checkbox" value="true" $expChk > Expose? 
						</label>
						<p>If enabled, any links with an expiry set will be marked with an unobtrusive green highlight in the admin interface.</p>
					</div>

					<br>
					<h3>Expiry Table Handling</h3>

					<div class="checkbox" style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<label>
							<input name="expiry_table_drop" type="hidden" value="false" />
							<input name="expiry_table_drop" type="checkbox" value="true" $tblChk > Drop it? 
						</label>
						<p>If selected, the expiry data will be flushed if the plugin gets disabled. Leave unchecked to preserve this data.</p>
					</div>

					<input type="hidden" name="nonce" value="$nonce" />
					<p><input type="submit" value="Submit" /></p>
				</form>
			</div>


			<div  id="stat_tab_exp_list" class="tab">

	 			<h3>Expiry URL List</h3>
				<h4>You can add an Expiry condition to a link that is already in the database</h4>

HTML;
	expiry_list_mgr($nonce);
echo <<<HTML
			</div>
			<div  id="stat_tab_prune" class="tab">

	 			<h3>Advanced: Database  Maintenance </h3>

				<p>There are 3 settings for this operation</p>
				<ul>
					<li><strong>Expired</strong>: Locates all links that are beyond expiration conditions, processes them accordingly.</li>
					<li><strong>Scrub</strong>: Dumps all expiry data. URL's remain in the database, only expiry data is stripped.</li>
					<li><strong>Killall</strong>: <span style="color:red">Warning!</span> Ruthlessly expires any link with expiration conditions before thier time.</li>
				</ul>

				<form method="post">

					<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
						<select name="expiry_admin_prune_type" size="1" >
							<option value="lazyorblind" >Select One</option>
							<option value="expired" >Expired</option>
							<option value="scrub" >Scrub</option>
							<option value="killall">Killall</option>
						</select>

						<label>
							<input name="expiry_admin_prune_do" type="hidden" value="false" />
							<input name="expiry_admin_prune_do" type="checkbox" value="true" > Do it? 
							<p>Be sure that you have the correct option, and check the box.</p>
						</label>
					</div>
	
					<input type="hidden" name="nonce" value="$nonce" />
					<p><input type="submit" value="Submit" /></p>

				<form method="post">
			</div>

			<div  id="stat_tab_api" class="tab">

				<p>Expiry will accept both GET and POST requests at the normal YOURLS API end point in order to:</p>
				<ul>
					<li>Add expiration data to a new short url</li>
					<li>Add expiration data to an old short url</li>
					<li>Retrieve expiration data for a short url</li>
					<li>Prune the database according to expiration data</li>
				</ul>
				<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
					<h3>Setting expiry data to a new short url</h3>
					<p>With the normal API request <code>action = "shorturl"</code>:</p>
			
					<p>For a <strong>click-count</strong> based expiry send:</p>
					<ul>
						<li><code>expiry = "click"</code></li>
						<ul>
							<li><code>count = NUMERIC_VALUE</code></li>
						</ul>
					</ul>
					<p>For a <strong>time</strong> based expiry send:</p>
					<ul>
						<li>expiry = "clock"</li>
						<ul> <li><code>age = NUMERIC_VALUE</code></li>
							<li><code>ageMod = (min, hr, day)</code></li>
						</ul>
					</ul>
					<p>If <code>count</code>, <code>age</code>, and <code>ageMod</code> values are not set, site default values will be used.</p> 
					<p><strong>Optional</strong>: set a post-expiration fallback URL:</p>
					<ul>
						<li><code>postx = URL</code></li>
					</ul>
				</div>
					<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
					<h3>Setting expiry data to an old short url</h3>
					<p>This action requires authenitcation. Along with auth data, and using the same parameters as above, send the following:</p> 
					<ul>
						<li><code>action = "expiry"</code></li>
						<li><code>shorturl = URL</code></li>
					</ul>
				</div>				
				<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
					<h3>Retrieving expiry data for any short url</h3>
					<p>Send the new action:</p>
					<ul>
						<li><code>action = "expiry-stats"</code></li>
						<li><code>shorturl = URL</code></li>
					</ul>
				</div>
				<div style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue;">
					<h3>Prune the database</h3>
					<p>These actions require authenitcation. Along with auth data, send one of the following:</p> 
				
					<ul>
						<li><code>action = "prune"</code></li>
						<ul>
							<li><code>scope = "expired"</code></li>
							<li><code>scope = "scrub"</code></li>
							<li><code>scope = "killall"</code></li>
						</ul>
					</ul>
					<p>See the Prune tab for explanations of these functions</p>

					<h4>Cron example:</h3>
					<p>Use the following pre-formatted example to set up a daily cron to prune your databse of expired links:</p>
					 <iframe src="data:text/html;charset=utf-8,$cronEG" width="100%" height="51"/></iframe>
					<p>Look here for more info on <a href="https://help.ubuntu.com/community/CronHowto" target="_blank" >cron</a> and <a href="https://www.gnu.org/software/wget/manual/html_node/HTTP-Options.html" target="_blank">wget</a>.</p>
				</div>
			</div>
		</div>
	</div>
			
HTML;
		
}
// Display page 0.1 - the expiry list
function expiry_list($nonce) {
	global $ydb;
echo <<<HTML
	<form method="post">
		<table id="expiry_table" border="1" cellpadding="5">
			<thead>
				<tr>
					<th>Alias</th>
					<th>Expiry Type</th>
					<th>Clicks</th>
					<th>Timer</th>
					<th>Time Unit</th>
					<th>PostX Destination (optional)</th>

					<th>&nbsp;</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td><input type="text" name="shorturl" id="shorturl" size="8" value=""></td>
					<td>
						<select name="expiry" id="expiry" size="1" >
							<option value="none" selected="selected" >Select  One</option>
							<option value="click">Click Counts</option>
							<option value="clock">Timer</option>
						</select>
					</td>
					<td><input type="text" size="3" name="count" id="count" value="" disabled ></td>
					<td><input type="text" size="3" name="age" id="age" value="" disabled ></td>
					<td>
						<select name="ageMod" id="ageMod" size="1" disabled >
							<option value="">Select One</option>
							<option value="min">Minutes</option>
							<option value="hour">Hours</option>
							<option value="day" >Days</option>
						</select>
					</td>
					<td><input type="text" name="postx" id="postx" size="" disabled></td>
					<td colspan=3 align=right>
						<input type=submit name="submit" value="Submit">
						<input type="hidden" name="nonce" value="$nonce" />
					</td>
				</tr>
HTML;
	// populate table rows with expiry data if there is any

	$table = YOURLS_DB_PREFIX . 'expiry';
	$sql = "SELECT * FROM `$table` ORDER BY timestamp DESC";
	$expiry_list = $ydb->fetchObjects($sql);
	if($expiry_list) {
		foreach( $expiry_list as $expiry ) {
			$base	= YOURLS_SITE;
			$kword  = $expiry->keyword;
			$type   = $expiry->type;
			$postx  = $expiry->postexpire;
			$death  = null;
			$click  = null;
			if( $type == 'clock' ) {
				$fresh  = $expiry->timestamp;
				$stale  = $expiry->shelflife;
				$death  = ($stale - (time() - $fresh));
				$death  = expiry_age_mod_reverse($death);
			}
			if( $type == 'click' ) {
				$life  = $expiry->click;
				$stats  = yourls_get_keyword_stats( $kword );
				$link = $stats['link'];
				$lived = $link['clicks'];
				$click = $life - $lived;
			}
			
			$remove = ''. $_SERVER['PHP_SELF'] .'?page=expiry&action=remove&key='. $kword .'';
			$strip  = ''. $_SERVER['PHP_SELF'] .'?page=expiry&action=no_postx&key='. $kword .'';
			// print if there is any data
			echo <<<HTML
				<tr>
					<td>$kword</td>
					<td>$type</td>
					<td>$click</td>
					<td>$death</td>
					<td></td>
					<td>$postx</td>
					<td><a href="$remove">Remove Expiry <img src="$base/images/delete.png" title="UnExpire" border=0></a></td>
					<td><a href="$strip">Strip Postx <img src="$base/images/delete.png" title="UnPostExpiry" border=0></a></td>
				</tr>
HTML;
		}
	}
echo <<<HTML
			</tbody>
		</table>
	</form>
	<script>
		document.getElementById('expiry').addEventListener('change', function () {
			 if (this.value == "click") {
					$('#count').prop('disabled', false);
					$('#age').prop('disabled', true);      
					$('#ageMod').prop('disabled', true);      
					$('#postx').prop('disabled', false);       
				}
			 if (this.value == "clock") {
					$('#count').prop('disabled', true);
					$('#age').prop('disabled', false);      
					$('#ageMod').prop('disabled', false);      
					$('#postx').prop('disabled', false);       
				}
		});
		function getExpiryCookie(name) {
			var nameEQ = name + "=";
			var ca = document.cookie.split(';');
			for(var i=0;i < ca.length;i++) {
				var c = ca[i];
				while (c.charAt(0)==' ') c = c.substring(1,c.length);
				if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
			}
			return null;
		}
		var alias = getExpiryCookie('expiry');
		if (alias != "") {
         document.getElementById('shorturl').value = alias;
			$(window).on("unload", function() {
				document.cookie = 'expiry'+'=; Max-Age=-99999999; SameSite=Strict;';  
			});
		}
	</script>
HTML;
}

// Change Admin page New URL submission form
yourls_add_filter( 'shunt_html_addnew', function ( $shunt, $url, $keyword ) {

	$opt = expiry_config();
	$e_p = $c_c = $t_t = 'none';
	$gn = $gt = $gc = $aV = $aMn = $aMh = $aMm = $aMd = $cV = NULL;

	switch ( $opt[9] ) {

		case 'click':
			$e_p = $c_c = 'style';
			$gc = 'selected="selected"';
			$cV = $opt[8];
			break;

		case 'clock':
			$e_p = $t_t = 'style';
			$gt = 'selected="selected"';
			$aV = $opt[6];

			switch ( $opt[7] ) {
				case 'min':
					$aMm = 'selected="selected"';
					break;
				case 'hour':
					$aMh = 'selected="selected"';
					break;
				default:
					$aMd = 'selected="selected"';
			}

			break;
		default:
			$gn = $aMn = 'selected="selected"';
	}

	?>
	<main role="main">
	<div id="new_url">
		<div>
			<form id="new_url_form" action="" method="get">
				<div>
					<strong><?php yourls_e( 'Enter the URL' ); ?></strong>:
					<input type="text" id="add-url" name="url" value="<?php echo $url; ?>" class="text" size="80" placeholder="https://" />
					<?php yourls_e( 'Optional '); ?> : <strong><?php yourls_e('Custom short URL'); ?></strong>:<input type="text" id="add-keyword" name="keyword" value="<?php echo $keyword; ?>" class="text" size="8" />
					<?php yourls_nonce_field( 'add_url', 'nonce-add' ); ?>
					<input type="button" id="add-button" name="add-button" value="<?php yourls_e( 'Shorten The URL' ); ?>" class="button" onclick="add_link_expiry();" />
					</br></br>
					<label for="expiry"><strong>Short Link Expiration Type</strong>:</label>
					<select name="expiry" id="expiry" data-role="slider" > Select One
						<option value="" 		<?php echo $gn; ?> >None</option>
						<option value="clock" 	<?php echo $gt; ?> >Timer</option>
						<option value="click" 	<?php echo $gc; ?> >Click Counter</option>
					</select>
					<div id="expiry_params" style="padding-left: 10pt;border-left:1px solid blue;border-bottom:1px solid blue; display:<?php echo $e_p; ?>;">
						<div style="margin:auto;width:150px;text-align:left;" >
							<div id="tick_tock" style="display:<?php echo $t_t; ?>">
								<input style="width:50px;" type="number" name="age" id="age" value="<?php echo $aV; ?>" min="0">
									<select name="ageMod" id="ageMod" size="1" >
										<option value="" 	<?php echo $aMn; ?> >Select One</option>
										<option value="min" <?php echo $aMm; ?> >Minutes</option>
										<option value="hour"<?php echo $aMh; ?> >Hours</option>
										<option value="day" <?php echo $aMd; ?> >Days</option>
									</select>
							</div>
							<div id="clip_clop" style="display:<?php echo $c_c; ?>">
								<input  style="width:50px;" type="number" name="count" id="count" value="<?php echo $cV; ?>" min="0" > Click limit.
							</div>
						</div>
						<input type="text" id="postx" name="postx" class="text" size="40" placeholder="leave blank for none"/> <strong>Fallback URL</strong>
					</div>
				</div>
			</form>
			<div id="feedback" style="display:none"></div>
		</div>
		<?php yourls_do_action( 'html_addnew' ); ?>
	</div>
	<script>
		document.getElementById('expiry').addEventListener('change', function () {
			var style = this.value !== "" ? 'block' : 'none';
			document.getElementById('expiry_params').style.display = style;
			var style = this.value == "clock" ? 'block' : 'none';
			document.getElementById('tick_tock').style.display = style;
			var style = this.value == "click" ? 'block' : 'none';
			document.getElementById('clip_clop').style.display = style;
		});
	</script>
	<?php 
	return $shunt = true;
});

// Mark expiry links on admin page FIXME identify freshly added links
yourls_add_filter( 'table_add_row', function ($row, $keyword, $url, $title, $ip, $clicks, $timestamp) {
	
	global $ydb;
	
	// Check if this is wanted
	$expiry_expose = yourls_get_option( 'expiry_expose' ); 
	if($expiry_expose !== "false") {

		// If the keyword is set to expire, make the URL show in green;
		$table = YOURLS_DB_PREFIX . 'expiry';

		$sql = "SELECT * FROM $table WHERE `keyword` = :keyword";
		$binds = array('keyword' => $keyword);
		$expiry = $ydb->fetchOne($sql, $binds);
	
		if( $expiry ) {
			$old_key = '/td class="keyword"/';
			$new_key = 'td class="keyword" style="border-right: 6px solid green;"';
			$newrow = preg_replace($old_key, $new_key, $row);
			return $newrow;
		} else
			$newrow = $row;

		return $newrow;

	} else
		return $row;
});

// Expiry data in Share box on admin page
yourls_add_action('yourls_ajax_expiry-stats', function () {
	$shorturl = $_REQUEST['shorturl'];	
	$return = expiry_check( array( "expiry_infos" , $shorturl ) );
	echo json_encode($return);
});

// Add a Expiry Button to the Admin interface
yourls_add_filter( 'table_add_row_action_array', function ( $actions, $keyword ) {

	$list = YOURLS_SITE . "/admin/plugins.php?page=expiry#stat_tab_exp_list";
	$id = yourls_string2htmlid( $keyword );
	$expiry = array (
		'expiry' => array(
			'href'    => "$list",
			'id'      => "trlink-$id",
			'title'   => yourls_esc_attr__( 'Expiry' ),
			'anchor'  => yourls__( 'Add Expiry Data' ),
			'onclick' => "setExpiryCookie( 'expiry' , '$keyword' );",
			)
		);
	$result = array_merge( $actions, $expiry ); ;
 	return $result;
});

yourls_add_filter( 'table_head_start', function ($start) {
	return '<div style="text-align:center; padding-top: 5px;"id="exp_result" class="text-success"></div>'."\n".$start;
});

// Expiry data for info page stats tab
yourls_add_action('pre_yourls_info_stats', function ($keyword) {
	$infos = expiry_check( array( "expiry_infos" , $keyword[0] ) );
	echo "<strong>Expiry</strong>: " . $infos['simple'];
});

/*
 *
 * 	Form submissions
 *
 *
*/
// Options updater
function expiry_update_ops() {
	if(isset( $_POST['expiry_global_expiry'])) {
		// Check nonce
		yourls_verify_nonce( 'expiry' );

		yourls_update_option( 'expiry_global_expiry', $_POST['expiry_global_expiry'] );
		if(isset( $_POST['expiry_default_click'] )) 
			yourls_update_option( 'expiry_default_click', $_POST['expiry_default_click'] );
		if(isset( $_POST['expiry_default_age'] )) 
			yourls_update_option( 'expiry_default_age', $_POST['expiry_default_age'] );
		if(isset( $_POST['expiry_default_age_mod'] )) 
			yourls_update_option( 'expiry_default_age_mod', $_POST['expiry_default_age_mod'] );
		if(isset( $_POST['expiry_intercept'] )) 
			yourls_update_option( 'expiry_intercept', $_POST['expiry_intercept'] );
		if(isset( $_POST['expiry_custom'] )) 
			yourls_update_option( 'expiry_custom', $_POST['expiry_custom'] );
		if(isset( $_POST['expiry_global_post_expire_chk'] )) 
			yourls_update_option( 'expiry_global_post_expire_chk', $_POST['expiry_global_post_expire_chk'] );
		if(isset( $_POST['expiry_global_post_expire'] )) 
			yourls_update_option( 'expiry_global_post_expire', $_POST['expiry_global_post_expire'] );
		if(isset( $_POST['expiry_expose'] )) 
			yourls_update_option( 'expiry_expose', $_POST['expiry_expose'] );
		if(isset( $_POST['expiry_table_drop'] )) 
			yourls_update_option( 'expiry_table_drop', $_POST['expiry_table_drop'] );

	}
}

// Epirly List Mgr
function expiry_list_mgr($n) {

	// CHECK if UNSET form was submitted, handle expiry list
	if( isset( $_GET['action'] ) ) {
		global $ydb;
		// remove expiry data from a link (keeps link in YOURLS)
		if( $_GET['action'] == 'remove') {
			if( isset($_GET['key']) ) {
				$key = $_GET['key'];
				$table = YOURLS_DB_PREFIX . 'expiry';
				$binds = array('key' => $key);
				$sql = "DELETE FROM `$table` WHERE `keyword` = :key";
				$delete = $ydb->fetchAffected($sql, $binds);
			}
			// go to list
			expiry_list($n);
		}
		// remove fallback data from expiry (keeps expiration data)
		if( $_GET['action'] == 'no_postx') {
			if( isset($_GET['key']) ) {
				$key = $_GET['key'];
				$table = YOURLS_DB_PREFIX . 'expiry';
				$binds = array('key' => $key);
				$sql = "UPDATE `$table` SET `postexpire` = 'none' WHERE `keyword` = :key";
				$update = $ydb->fetchAffected($sql, $binds);
			}
			// go to list
			expiry_list($n);
		}
	}
	elseif( !empty($_POST) && isset( $_POST['shorturl'] ) && isset( $_POST['expiry'] ) ) {
		expiry_old_link();
		expiry_list($n);
	}
	else {
		expiry_list($n);
	}
}
// Prune Form
function expiry_flush() {
	if( isset( $_POST['expiry_admin_prune_do'] ) ) {
		if( $_POST['expiry_admin_prune_do'] == 'true' ) {
			// Check nonce
			yourls_verify_nonce( 'expiry' );
			$type = $_POST['expiry_admin_prune_type'];
			expiry_db_flush( $type );
			switch ($type) {
				case 'expired':
					echo '<font color="green">All expired links have beeen deleted from the system. Have a nice day.</font>';
					break;
				case 'scrub':
					echo '<font color="green">All links are now non-perishable. Have a nice day.</font>';
					break;
				case 'killall':
					echo '<font color="green">All links with expiration dates have been deleted. Have a nice day.</font>';
					break;
				case 'lazyorblind';
					echo '<font color="red">You submitted the form without selecting an option... try again.</font>';
					break;
				default:
					echo '<font color="red">Something went wrong, check your database.</font>';
			}
		} else {
			echo '<font color="red">You submitted the Prune without checking "Do it?"</font>';
		}
	}
}

/*
 *
 * Expiry Checking
 *
 *
*/
// Hook on basic redirect
yourls_add_action( 'redirect_shorturl', 'expiry_check' );
function expiry_check( $args ) {

	global $ydb;
	$keyword = str_replace( YOURLS_SITE . '/' , '', $args[1] ); // accept either 'http://ozh.in/abc' or 'abc'
	$keyword = yourls_sanitize_keyword( $keyword );
	$table = YOURLS_DB_PREFIX . 'expiry';
	$sql = "SELECT * FROM $table WHERE `keyword` = :keyword";
	$binds = array('keyword' => $keyword);
	$expiry = $ydb->fetchOne($sql, $binds);

	$result = false;

	if( $expiry ) {
		$expiry = (array)$expiry;
		if( $expiry['type'] == 'click' ) {

			$count 	= $expiry['click'];
			$stats  = yourls_get_keyword_stats( $keyword );
			$link = $stats['link'];
			$clicks = $link['clicks'];
			
			if ( $clicks >= $count )
				$result = 'click-bomb';

			$life = $count - $clicks;
		}

		elseif( $expiry['type'] == 'clock' ) {

			$fresh  = $expiry['timestamp'];
			$stale  = $expiry['shelflife'];

			if( ( time() - $fresh)  >= $stale )
				$result = 'time-bomb';	
			
			$death  = ($stale - (time() - $fresh));
			$life = expiry_age_mod_reverse($death);
		}
	
		$opt = expiry_config();
		$gpx = $opt[5] == 'false' ? null : $opt[4];
		$postx  = (isset($expiry['postexpire']) ? $expiry['postexpire'] : $gpx);

	} else {
		$expiry['type'] = 'none';
		$life = $postx = null;
	}
	
	if( $args[0] == "expiry_infos" )
		return expiry_stats_response (array ( $result, $expiry['type'], $life, $postx ) );

	if($result !== false)
		expiry_router($keyword, $result, $postx);
}

// expiry check ~ router
function expiry_router($keyword, $result, $postx) {
	// try to edit maybe
	if ( $postx !== null && $postx !=='' && $postx !== 'none' && $postx !== 'false') {

		if( yourls_edit_link( $postx, $keyword, $keyword ) ) {

			$args[0] = $keyword;
			expiry_cleanup( $args );

			if ( !yourls_is_API() && !defined('EXPIRY_CLI')) {
				yourls_redirect($postx, 302);
				die();
			}
		} else {
	
			$postx = null;
		}
	} 

	elseif( $postx == null || $postx == '' || $postx == 'none' ) {
	
		yourls_delete_link_by_keyword( $keyword );
		
		if ( !yourls_is_API() && !defined('EXPIRY_CLI')) {
		
			$expiry_intercept = yourls_get_option( 'expiry_intercept' );
			
			switch ($expiry_intercept) {
				case 'simple': 
					yourls_die('This short URL has expired.', 'Link Expired', '403');
				case 'template': 
					expiry_display_expired($keyword, $result);
				case 'custom':
					$expiry_custom = yourls_get_option( 'expiry_custom' );
					if ($expiry_custom !== 'none') { 
						yourls_redirect( $expiry_custom, 302 );
						die();
					} else {
						yourls_die('This short URL has expired.', 'Link Expired', '403');
					}
				default:
					yourls_die('This short URL has expired.', 'Link Expired', '403');
			}
		}
	}
	
}

// expiry info response
function expiry_stats_response( $infos ) {

	if( isset($infos[3])  && $infos[3] !=='' && $infos[3] !== 'none') { 
		$postx_info = "This link will redirect to ".$infos[3]." after expiration.";
		$postx_data = $infos[3];
	} else {
		$postx_info = null;
		$postx_data = 'none';
	}

	if($infos[0] !== false) {
		return array(
			'statusCode' => 200,
			'expiry'	 => $infos[1],
			'postx'		 => $postx_data,
			'simple'     => "This link is a ". $infos[0] .", it is beyond expiration. ".$postx_info,
			'message'    => "This link is a ". $infos[0] .", it is beyond expiration. ".$postx_info
		);
	} else {

		switch ($infos[1]) {
			case 'none':
				return array(
					'statusCode' => 200,
					'expiry		'=> 'none',
					'simple'     => "No expiry data set.",
					'message'    => "No expiry data set."
				);
				break;
			case 'click':
				return array(
					'statusCode' => 200,
					'expiry'	 => 'click',
					'countdown'  => $infos[2],
					'postx'		 => $postx_data,
					'simple'     => "Short URL has ".$infos[2]." clicks left. ".$postx_info,
					'message'    => "Short URL has ".$infos[2]." clicks left. ".$postx_info
				);
				break;

			case 'clock':
				return array(
					'statusCode' => 200,
					'expiry_type'=> 'clock',
					'countdown'  => $infos[2],
					'postx'		 => $postx_data,
					'simple'     => "Short URL will expire in ".$infos[2]." . ".$postx_info,
					'message'    => "Short URL will expire in ".$infos[2]." . ".$postx_info
				);
				break;
			default:				
				return array(
					'statusCode' => 400,
					'simple'     => "Not able to retrieve expiry data, please check your configuraiton (call).",
					'message'    => "Not able to retrieve expiry data, please check your configuraiton (call)."
				);
				break;
		}
	}
}

/*
 *
 *	API
 *
 *
*/
// Expire new links
yourls_add_filter( 'add_new_link', function ( $return, $url , $keyword, $title ) { 

	// this method tolelrates no error in short url creation
	if(isset ( $return['code'] ) ) {
		switch( $return['code'] ) {
			case 'error:url':
				$return['expiry'] = 'Error: use "action => expiry" to add expiration data to a pre-esxisting url. No expiry data set';
				return $return;
			default:
				return $return;
		}
	}

	$opt = expiry_config();

	$type = isset($_REQUEST['expiry']) ? $_REQUEST['expiry'] : $opt[9];

	switch( $type ) {
		case 'click': 									// ex. "expiry=click"
			$click = (isset($_REQUEST['count']) ? $_REQUEST['count'] : $opt[8]);	// ex. "count=50"
			if( !is_numeric( $click ) ){	
				$return['expiry'] = "'count' must be a valid number, no expiry set";
				return $return;
			}

			$fresh = $stale = 'dummy';	
			$return['expiry'] = "$click click expiry set";
			break;
		case 'clock':									// ex. "expiry=clock"
			$age = (isset($_REQUEST['age']) ? $_REQUEST['age'] : $opt[6]); 		// ex. "age=3"
			if( !is_numeric( $age ) ) {
				$return['expiry'] = "'age' must be a valid number, no expiry set";
				return $return;
			}

			$ageMod = (isset($_REQUEST['ageMod']) ? $_REQUEST['ageMod'] : $opt[7]); // ex. "ageMod=hour"
			if( !in_array( $ageMod, array( 'min', 'hour', 'day' ) ) ) {
				$return['expiry'] = "'ageMod' must be 'min', 'day', or 'hour', no expiry set";
				return $return;
			}

			$fresh = time();
			$stale = expiry_age_mod($age, $ageMod);
			$click = 'dummy';
			$return['expiry'] = "$age $ageMod expiry set.";
			break;
		default:
			return $return;
		
	}

	$gpx    = $opt[5] == 'false' ? null : $opt[4];
	$postx  = (isset($_REQUEST['postx']) ? $_REQUEST['postx'] : $gpx); 	// ex. "postx=https://example.com"
	if($postx !== null && $postx !== 'none') {
		$return['postx'] = $postx;
		if (!filter_var($postx, FILTER_VALIDATE_URL) ) {
			$return['postx'] = "invalid url, not set";
			$postx = 'none';
		}
		elseif(!yourls_is_allowed_protocol( $postx ) ){
			$return['postx'] = "disallowed protocol, not set";
			$postx = 'none';
		}
	}

	// All set, put it in the database
	global $ydb;
	$table = YOURLS_DB_PREFIX . 'expiry';

	$binds = array( 'keyword' => $keyword,
			'type' => $type,
			'click' => $click,
			'fresh' => $fresh,
			'stale' => $stale,
			'postx' => $postx );
				
	$sql = "REPLACE INTO $table (keyword, type, click, timestamp, shelflife, postexpire) VALUES (:keyword, :type, :click, :fresh, :stale, :postx)";
	
	$insert = $ydb->fetchAffected($sql, $binds);
		

	return yourls_apply_filter( 'after_expiry_new_link', $return, $url, $keyword, $title );
});

// Expiry old links
yourls_add_filter( 'api_action_expiry', 'expiry_old_link' );
function expiry_old_link() {
	
	$auth = yourls_is_valid_user();
	if( $auth !== true ) {
		$format = ( isset($_REQUEST['format']) ? $_REQUEST['format'] : 'xml' );
		$callback = ( isset($_REQUEST['callback']) ? $_REQUEST['callback'] : '' );
		yourls_api_output( $format, array(
			'simple' => $auth,
			'message' => $auth,
			'errorCode' => 403,
			'callback' => $callback,
		) );
	}

	if( !isset( $_REQUEST['shorturl'] ) ) {
		return array(
			'statusCode' => 400,
			'simple'     => "Need a 'shorturl' parameter",
			'message'    => 'error: missing shorturl param',
		);	
	}

	$shorturl = $_REQUEST['shorturl'];

	if( !yourls_is_shorturl( $shorturl ) ) {
		return array(
			'statusCode' => 400,
			'simple'     => "Not a valid short url",
			'message'    => 'error: bad url',
		);	
	}

	$keyword = str_replace( YOURLS_SITE . '/' , '', $shorturl ); // accept either 'http://ozh.in/abc' or 'abc'

	$keyword = yourls_sanitize_keyword( $keyword );
	$url = yourls_get_keyword_longurl( $keyword );
	$title = yourls_get_keyword_title( $keyword );

	$opt = expiry_config();

	$type = isset($_REQUEST['expiry']) ? $_REQUEST['expiry'] : $opt[9];

	switch( $type ) {

		case 'click': 									// ex. "expiry=click"
			$count = (isset($_REQUEST['count']) ? $_REQUEST['count'] : $opt[8]);	// ex. "count=50"
			if( !is_numeric( $count ) ){
				return array(
					'statusCode' => 400,
					'simple'     => "'count' must be a valid number, no expiry set",
					'message'    => "error: 'count' must be a valid number",
				);		
			}

			$fresh = $stale = null;	
			$return['expiry'] = "$count click expiry set";
			$return['expiry_type'] = "click";
			$return['expiry_life'] = "$count";
			break;

		case 'clock':									// ex. "expiry=clock"
			$age = (isset($_REQUEST['age']) ? $_REQUEST['age'] : $opt[6]);	// ex. "age=3"
			if( !is_numeric( $age ) ) {
				return array(
					'statusCode' => 400,
					'simple'     => "'age' must be a valid number, no expiry set",
					'message'    => "error: 'age' must be a valid number",
				);		
			}

			$ageMod = (isset($_REQUEST['ageMod']) ? $_REQUEST['ageMod'] : $opt[7]); // ex. "ageMod=hour"
			if( !in_array( $ageMod, array( 'min', 'hour', 'day' ) ) ) {
				return array(
					'statusCode' => 400,
					'simple'     => "'ageMod' must be set to 'min', 'day', or 'hour', no expiry set",
					'message'    => "error: 'ageMod' must be set to 'min', 'day', or 'hour'",
				);		
			}

			$count = null;
			$fresh = time();
			$stale = expiry_age_mod($age, $ageMod);
			$return['expiry'] = "$age $ageMod expiry set.";
			$return['expiry_type'] = "clock";
			$return['expiry_life'] = "$stale"; // in seconds
			break;

		case 'none':
			return array(
				'statusCode' => 400,
				'simple'     => "'expiry' must be set to 'click' or 'clock', no expiry set",
				'message'    => "error: 'expiry' must be set to 'click' or 'clock'",
			);		
	}

	$gpx    = $opt[5] == 'false' ? null : $opt[4];
	$postx  = (isset($_REQUEST['postx']) ? $_REQUEST['postx'] : $gpx);	// ex. "postx=https://example.com"
	if($postx !== null && $postx !== 'none') {
		$return['postx'] = $postx;
		if (!filter_var($postx, FILTER_VALIDATE_URL) ) {
			$return['postx'] = "error: invalid url, not set";
			$postx = null;
		}
		elseif(!yourls_is_allowed_protocol( $postx ) ){
			$return['postx'] = "error: disallowed protocol, not set";
			$postx = null;
		}
	}
	$shorturl = YOURLS_SITE . '/' . $keyword;
	$return['statusCode'] = "200";
	$return['message'] = "success: expiry set";
	$return['shorturl'] = $shorturl;
	$return['url'] = $url;
	$return['title'] = $title;
	$return['simple'] = "Success: '$type' expiry set for $shorturl ";
	
	// All set, put it in the database
	global $ydb;
	$table = YOURLS_DB_PREFIX . 'expiry';
	$binds = array( 	'keyword' 	=> $keyword,
				'type'  	=> $type,
				'click' 	=> $count,
				'fresh' 	=> $fresh,
				'stale' 	=> $stale,
				'postx' 	=> $postx );
			
	$sql = "REPLACE INTO $table (keyword, type, click, timestamp, shelflife, postexpire) VALUES (:keyword, :type, :click, :fresh, :stale, :postx)";
	
	$insert = $ydb->fetchAffected($sql, $binds);

	return yourls_apply_filter( 'after_expiry_old_link', $return, $url, $keyword, $title );
}
// Check Shortlink expiry data
yourls_add_filter( 'api_action_expiry-stats', function () {

	if( !isset( $_REQUEST['shorturl'] ) ) {
		return array(
			'statusCode' => 400,
			'simple'     => "Need a 'shorturl' parameter",
			'message'    => 'error: missing shorturl param',
		);	
	}

	$r = $_REQUEST['shorturl'];

	if( !yourls_is_shorturl( $r ) ) {
		return array(
			'statusCode' => 400,
			'simple'     => "Not a valid short url",
			'message'    => 'error: bad url',
		);	
	}

	$return = expiry_check( array( "expiry_infos" , $r ) );
	return $return;
});

// Prune away expired links
yourls_add_filter( 'api_action_prune', function () {

	$auth = yourls_is_valid_user();
	if( $auth !== true ) {
		$format = ( isset($_REQUEST['format']) ? $_REQUEST['format'] : 'xml' );
		$callback = ( isset($_REQUEST['callback']) ? $_REQUEST['callback'] : '' );
		yourls_api_output( $format, array(
			'simple' => $auth,
			'message' => $auth,
			'errorCode' => 403,
			'callback' => $callback,
		) );
	}

	// We need a scope for the prune
	if( !isset( $_REQUEST['scope'] ) ) {
		return array(
			'statusCode' => 400,
			'simple'     => "Need a 'scope' parameter",
			'message'    => "error: missing 'scope' param",
		);	
	}
	
	// Scope must be in range
	if( !in_array( $_REQUEST['scope'], array( 'expired', 'scrub', 'killall' ) ) ) {
		return array(
			'statusCode' => 400,
			'simple'     => "Error: 'scope' must be set to 'expired', 'scrub' or 'killall'",
			'message'    => "error: bad param value for 'scope'",
			);
	}

	$type = $_REQUEST['scope'];
	switch( $type ) {
		case 'expired':
			
			if( expiry_db_flush( $type ) ) {
				return array(
					'statusCode' => 200,
					'simple'     => "Expired links have been pruned",
					'message'    => 'success: pruned',
				);
			} else {
				return array(
					'statusCode' => 500,
					'simple'     => 'Error: could not prune expiry, not sure why :-/',
					'message'    => 'error: unknown error',
				);
			}

		case 'scrub':
			
			if( expiry_db_flush( $type ) ) {
				return array(
					'statusCode' => 200,
					'simple'     => "Expirations have been stripped from all links",
					'message'    => 'success: pruned',
				);
			} else {
				return array(
					'statusCode' => 500,
					'simple'     => 'Error: could not prune expiry, not sure why :-/',
					'message'    => 'error: unknown error',
				);
			}

		case 'killall':
			
			if( expiry_db_flush( $type ) ) {
				return array(
					'statusCode' => 200,
					'simple'     => "All perishable links have been pruned",
					'message'    => 'success: pruned',
				);
			} else {
				return array(
					'statusCode' => 500,
					'simple'     => 'Error: could not prune expiry, not sure why :-/',
					'message'    => 'error: unknown error',
				);
			}
	}
});

/*
 *
 *	Database
 *
 *
*/
// temporary update DB script

if (!defined( 'EXPIRY_DB_UPDATE' ))
	define( 'EXPIRY_DB_UPDATE', false );
if ( EXPIRY_DB_UPDATE ) 
	yourls_add_action( 'plugins_loaded', 'expiry_update_DB' );
function expiry_update_DB () {
	yourls_delete_option('expiry_init');
	global $ydb;
	$table = 'expiry';
	if ( YOURLS_DB_PREFIX ) {
		try {
			$sql = "DESCRIBE `".YOURLS_DB_PREFIX . $table."`";
			$fix = $ydb->fetchAffected($sql);
		} catch (PDOException $e) {
			$sql = "RENAME TABLE `".$table."` TO  `".YOURLS_DB_PREFIX.$table."`";
			$fix = $ydb->fetchAffected($sql);
		}
		
		$table = YOURLS_DB_PREFIX . $table;
	}
	
	try {
	    	$sql = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
	    		WHERE TABLE_NAME = `".$table."`
	    		AND ENGINE = 'INNODB' LIMIT 1";
	    	$fix = $ydb->fetchAffected($sql);
    	} catch (PDOException $e) {
		$sql = "ALTER TABLE `".$table."` ENGINE = INNODB;";
		$fix = $ydb->fetchAffected($sql);
	}
}
// Create tables for this plugin when activated
yourls_add_action( 'activated_expiry/plugin.php', function () {

	global $ydb;
	// Create the expiry table
	$table = YOURLS_DB_PREFIX . 'expiry';
	$table_expiry  = "CREATE TABLE IF NOT EXISTS `".$table."` (";
	$table_expiry .= "keyword varchar(200) NOT NULL, ";
	$table_expiry .= "type varchar(5) NOT NULL, ";
	$table_expiry .= "click varchar(5), ";
	$table_expiry .= "timestamp varchar(20), ";
	$table_expiry .= "shelflife varchar(20), ";
	$table_expiry .= "postexpire varchar(200), ";
	$table_expiry .= "PRIMARY KEY (keyword) ";
	$table_expiry .= ") ENGINE=InnoDB DEFAULT CHARSET=latin1;";

	$tables = $ydb->fetchAffected($table_expiry);
});

// Delete table when plugin is deactivated
yourls_add_action('deactivated_expiry/plugin.php', function () {
	$expiry_table_drop = yourls_get_option('expiry_table_drop');
	if ( $expiry_table_drop !== 'false' ) {
		global $ydb;
		$table = YOURLS_DB_PREFIX . 'expiry';
		$sql = "DROP TABLE IF EXISTS $table";
		$ydb->fetchAffected($sql);
	}
});

// DB Flushing
function expiry_db_flush( $type ) {
	global $ydb;
	$table = YOURLS_DB_PREFIX . 'expiry';
	switch ( $type ) {
		// remove expiry data from all links & preserve the short url	
		case 'scrub':
			$sql = "TRUNCATE TABLE $table";
			$ydb->fetchAffected($sql);
			$result = true;
			break;
			
		// delete every short url that is set to expire	
		case 'killall': // nuke
			$sql = "SELECT * FROM `$table` ORDER BY timestamp DESC";
			$expiry_list = $ydb->fetchObjects($sql);
			if($expiry_list) {
				foreach( $expiry_list as $expiry ) {
					$keyword = $expiry->keyword;
					yourls_delete_link_by_keyword( $keyword );
				}
			}

			$result = true;	
			break;
		
		case 'expired': // get rid of expired links that have not been triggered
		default:

			$sql = "SELECT * FROM `$table` ORDER BY timestamp DESC";
			$expiry_list = $ydb->fetchObjects($sql);
				
			if($expiry_list) {
				foreach( $expiry_list as $expiry ) {
					$keyword = $expiry->keyword;
					$args = array("prune", $keyword);
					expiry_check($args);
				}
			}

			$result = true;
			break;
	}

	return $result;
}
// auto-delete expiry records 
yourls_add_action( 'delete_link', 'expiry_cleanup' );	// cleanup on keyword deletion
function expiry_cleanup( $args ) {
	global $ydb;

    	$keyword = $args[0]; // Keyword to delete

	// Delete the expiry data, no need for it anymore
	$table = YOURLS_DB_PREFIX . 'expiry';

	$binds = array( 'keyword' => $keyword );
	$sql = "DELETE FROM $table WHERE `keyword` = :keyword";
	$ydb->fetchAffected($sql, $binds);


}

/*
 *
 *	Helpers
 *
 *
*/
// Get options and set defaults
function expiry_config() {

	// Get values from DB
	$intercept = yourls_get_option( 'expiry_intercept' );
	$int_cust  = yourls_get_option( 'expiry_custom' );
	$tbl_drop  = yourls_get_option( 'expiry_table_drop' );
	$expose	   = yourls_get_option( 'expiry_expose' );
	$gpx	   = yourls_get_option( 'expiry_global_post_expire' );
	$gpx_chk   = yourls_get_option( 'expiry_global_post_expire_chk' );
	$age	   = yourls_get_option( 'expiry_default_age' ); 
	$ageMod	   = yourls_get_option( 'expiry_default_age_mod' );
	$click	   = yourls_get_option( 'expiry_default_click' );
	$global	   = yourls_get_option( 'expiry_global_expiry' );
	
	// Set defaults if necessary
	if( $intercept	== null ) $intercept 	= 'simple';
	if( $int_cust	== null ) $int_cust		= 'none';
	if( $tbl_drop 	== null ) $tbl_drop 	= 'false';
	if( $expose		== null ) $expose		= 'true';
//	if( $gpx		== null ) $gpx			= 'false';
	if( $gpx_chk	== null ) $gpx_chk		= 'false';
	if( $age		== null ) $age			= '3';
	if( $ageMod		== null ) $ageMod		= 'day';
	if( $click		== null ) $click		= '50';
	if( $global		== null ) $global		= 'none';

	if( YOURLS_UNIQUE_URLS == true) $gpx_chk = 'false';

	return array(
	$intercept,		// opt[0]
	$int_cust,		// opt[1]
	$tbl_drop,		// opt[2]
	$expose,		// opt[3]
	$gpx,			// opt[4]
	$gpx_chk,		// opt[5]
	$age,			// opt[6]
	$ageMod,		// opt[7]
	$click,			// opt[8]
	$global			// opt[9]
	);
}

// Adjust human readable time into seconds
function expiry_age_mod($age, $ageMod) {
	switch ($ageMod) {
		case 'day':
			$age = $age * 24 * 60 * 60;
			break;
		case 'hour':
			$age = $age * 60 * 60;
			break;
		case 'min':
			$age = $age * 60;
			break;
		default:
			$age = $age;
	}
	return $age;
}
// Adjust seconds into human readable time
function expiry_age_mod_reverse($ss) {

	$s = $ss%60;
	$m = floor(($ss%3600)/60);
	$h = floor(($ss%86400)/3600);
	$d = floor($ss/86400) . "d ";

	if ($s < 10) $s = '0' . $s;
	if ($m < 10) $m = '0' . $m;
	if ($h < 10) $h = '0' . $h;
	if ($d == "0d ") $d = "";

	return "$d$h"."h".$m.":"."$s";

}
// intercept template
function expiry_display_expired($keyword, $result) {

	$base	= YOURLS_SITE;
	$img	= yourls_plugin_url( dirname( __FILE__ ).'/assets/caution.png' );
	$css 	= yourls_plugin_url( dirname( __FILE__ ).'/assets/bootstrap.min.css' );

	$vars = array();
		$vars['keyword'] 	= $keyword;
		$vars['result'] 	= $result;	//TODO - put in intercept.php
		$vars['base'] 		= $base;
		$vars['img'] 		= $img;
		$vars['css'] 		= $css;

	$intercept = file_get_contents( dirname( __FILE__ ) . '/assets/intercept.php' );
	// Replace all %stuff% in intercept.php with variable $stuff
	$intercept = preg_replace_callback( '/%([^%]+)?%/', function( $match ) use( $vars ) { return $vars[ $match[1] ]; }, $intercept );

	echo $intercept;
	die();
}
