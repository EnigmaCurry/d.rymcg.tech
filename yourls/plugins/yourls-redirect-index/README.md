Redirect Index
==============
Plugin for [YOURLS](http://yourls.org) `<1.4>` and newer. 

Description
-----------
This plugin allows you to redirect the user to another site if they go to the base directory of your YOURLS installation. Ordinarily, most web servers just display a directory listing or a simple error page, but this allows you to redirect your users to a more friendly page. The URL of the site you want to redirect to can be set up in the YOURLS admin panel.

Installation
------------
1. Download the plugin from the [releases page](https://github.com/tomslominski/yourls-redirect-index/releases).
2. Drop the downloaded folder into the `/user/plugins` directory of your YOURLS installation and make sure to rename it to `redirect-index`.
3. Move the `index.php` folder out of that directory and into your YOURLS base directory.
4. Go to the Plugins administration page ( *eg* `http://sho.rt/admin/plugins.php` ) and activate the plugin.
5. Set up the URL from the settings page ( *eg* `http://sho.rt/admin/plugins.php?page=redirindex` ) and have fun!

Translating
-----------
Redirect Index simply uses whatever language YOURLS uses, as described [here](https://github.com/YOURLS/YOURLS/wiki/YOURLS-in-your-language#install-yourls-in-your-language).

If you want to translate Redirect Index into your own language, [this blog post](http://blog.yourls.org/2013/02/workshop-how-to-create-your-own-translation-file-for-yourls/) from YOURLS describes how to do it. You can find the latest .pot file in the `translations` folder of the plugin directory. Please follow the contributing guidelines below to add your translation to Redirect Index.

Contributing
------------
If you have any issues with the way Redirect Index works, you want to suggest a feature or you believe you have found a bug, please submit an issue using GitHub's [issue system](https://github.com/tomslominski/yourls-redirect-index/issues). However, please remember that the developers work on this project in their spare time.

If you'd like to contribute some code to Redirect Index, please open an issue first to discuss whether your patch will be accepted. If it has been agreed that your patch will be accepted, please fork the repository and submit a pull request when ready.

Licensing
---------
Just like YOURLS, Redirect Index is licensed under the MIT license. Basically, you can do whatever you want with it. As this plugin works behind the scenes, you don't even really have to give attribution. There is no guarantee that this software will work.

You can find the full license in the root directory of Redirect Index, under LICENSE.md.
