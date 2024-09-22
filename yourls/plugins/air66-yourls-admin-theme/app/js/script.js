$( document ).ready(function() {
	// Get the theme URL
  var url;
  if ($('meta[name=pluginURL]').attr("content")) {
    url = $('meta[name=pluginURL]').attr("content");
  } else {
    // If for some reason we can't find the URL attribute
    url = "/user/plugins/air66Theme";
  }
	
// Detect login page
  if ($("body").hasClass("login")) {
	  
	  $("#login").prepend('<img class="air66-logo" src="' + url + '/dist/images/a66-logo.svg" alt="Air 66 Design Ltd Logo">');
  }
	
	// Remove the YOURLS header
	$("header[role=banner]").hide();
	$("header[role=banner]").remove();
	
	// remove help link in nav 
	$('#admin_menu_help_link').remove();
	
	$('#admin_menu').append('<li class="admin_menu_toplevel"><a href="https://air66design.com" target="_blank">Contact Air 66 Design</a></li>');
	
	// Add New A66 header 
	$("body").prepend($('<header class="site-header">').load(url + '/dist/html/header.php', function() {
		// run add header content function
		a66_add_header_content();
		
		$('body').prepend('<div class="nav-overlay"></div>');
		// add air 66 design link to menu
		
		// Nav icon toggle
		$('#menu-icon').click(function(){
			$(this).toggleClass('open');
			$('nav, .nav-overlay').toggleClass('nav-open');
		});
		
		if ($("body").hasClass("index")) {
			
			// Add content padding to suit new URL section
			//$("#wrap").css("padding-top", "200px");
			// Hide YOURLS new URL section
			$("#new_url").hide();
			// Grab the nonce id
			var nonce = $("#nonce-add").val();

			// Remove the YOURLS new URL Section
			$("#new_url").remove();
			
			$(".index").prepend($('<div class="form-wrap">').load(url + '/dist/html/form.php', function () {
			  $("#nonce-add").val(nonce);
			}));
		} else {
			//$("#wrap").css("padding-top", "70px");
		}
	}));
	
	
	// Update favicon
  $('link[rel="shortcut icon"]').attr('href', url + "/dist/images/favicon.ico")
	
// wrap index table in table-responsive
	
	$('#main_table').wrap("<div class='table-responsive'></div>");
	$( "#main_table" ).addClass( "table" );
	
	// handle p tags
	
	$("p").each(function (index) {
    if (/Display/.test($(this).text()) || /Overall/.test($(this).text())) {
      // Move info on index page to the bottom
      $("main").append("<p>" + $(this).html() + "</p>");
      $(this).remove();
    } else if (/Powered by/.test($(this).text())) {
        // Update footer
        var content = $(this).html();
        var i = 77
        var updated_content = "Running on" + content.slice(13, i) + '& <a href="https://air66design.com/" title="Air 66 Design Ltd" target="_blank">Air 66 Design Ltd</a>' + content.slice(i-1)
        $(this).html(updated_content);
      }
  });
	
	// wrap div around data tabs so can scroll on small screens
	
	$('#stat_tab_stats, #stat_tab_location, #stat_tab_sources, #stat_tab_share').wrapAll('<div class="tab-scroll"></div>');
	
	// remove help link in nav 
	$('#admin_menu_help_link').remove();
	
	
	// add header function
	
	function a66_add_header_content() {
		$('.site-header').append('<div class="air66-logo-wrap"><a class="air66-logo-link" href="https://air66design.com" target="_blank"><img class="air66-logo" src="' + url + '/dist/images/a66-logo-wh.svg" alt="Air 66 Design Ltd Logo"></a></div>');
	}
	
	
	

	
});// end document.ready