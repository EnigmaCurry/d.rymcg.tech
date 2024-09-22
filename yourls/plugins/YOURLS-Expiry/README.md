# YOURLS-Expiry
[YOURLS](https://github.com/YOURLS/YOURLS) plugin to define conditions under which links will expire - time and click limited links

#### Installation
MASTER branch of this plugin works with YOURLS 1.7.10 +  
There is a separate branch for 1.7.9
 
As any YOURLS plugin:
-  Extract the `expiry` folder from this repo, and place it at `user/plugins/expiry`
-  Enable in admin area
##### Notes:
- The databse ought to create itself, if not, there is an sql file in the `expiry/assets` folder, make sure to add your database prefix where necessary.
- If upgrading from 2.1.x of this plugin to 2.2.x, set `define( 'EXPIRY_DB_UPDATE', true );` in `config.php` __for one page load__ in order to update the database, otherwise this plugin will not work. 
##### What's Working:
-  add per-link and/or global time based or click count limited links
-  update links already in database to have expiration conditions
-  upon shorturl expiration:
    - delete from YOURLS 
    - update short url's with an optional per link or global secondary URL
-  robust admin area features
   - optionally highlight expiry links in admin interface
   - seperate page to list all expiry links with details (time left, etc)
   - one-click management of expiry data, bulk or individual
   - admin page action link button
   - expiry data on admin page under share box
   - expiry functions in admin filtered by [AuthMgrPlus](https://github.com/joshp23/YOURLS-AuthMgrPlus), if installed
-  robust api interface (documentation provided)
   - add and update individual links with precise detail
   - manage database with a cron call (pre-formatted example provided)
      - prune expired links that haven't been visited in a while, etc.
   - get precise individual url expiry info
- cli interface for pruning
- add expiry data in various ways
   - via public interface (new url)
   - via regular admin new url form (new url)
   - via expiry page (old url)
      - directly or by way of admin area action link button

---
##### CLI:
To use the cli prune options, execute the `/PATH/TO/YOURLS/user/plugins/expiry/bin/prune.inc.php` script with the appropriate permissions. This script requires a valid yourls signature, and accepts a `scope` option which can be any of the following:

|option	|function|
|--|--|
|`expired`	| will prune off any expired links. __default__|
|`scrub`	| will remove expiry data from any links|
|`killall`| will early expire _any_ links with expiry data set|

These options are the same as the api options.

example use:
```
$ php /PATH/TO/YOURLS/user/plugins/expiry/bin/prune.inc.php --signature=blah0blah1 --scope=expired
```
Look to the first lines in prune.inc.php to adjust php memory and timeout limits for larger databases or Docker installations with limited memory. Disabled by default.

---
###### Note: 
 Uses code adapted from the [Change Error Msgs](https://github.com/adigitalife/yourls-change-error-messages) plugin.

### Tips
Dogecoin: DARhgg9q3HAWYZuN95DKnFonADrSWUimy3
