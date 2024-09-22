# Plugin for YOURLS : Force Lowercase [![Listed in Awesome YOURLS!](https://img.shields.io/badge/Awesome-YOURLS-C5A3BE)](https://github.com/YOURLS/awesome-yourls/)

## What for

Force short urls to lowercase so that http://sho.rt/ABC is the same as http://sho.rt/abc

## How to

* In `/user/plugins`, create a new folder named `force-lowercase`
* Drop these files in that directory
* Go to the Plugins administration page and activate the plugin 
* Have fun

## Disclaimer: this is stupid

The web is case sensitive, [google.com/ABOUT](https://www.google.com/ABOUT) is different from [google.com/about](https://www.google.com/about). Deal with it.

More about this: see http://www.w3.org/TR/WD-html40-970708/htmlweb.html and particularly the part that says:
>URLs in general are case-sensitive (with the exception of machine names). There may be URLs, or parts of URLs, where case doesn't matter, but identifying these may not be easy. Users should always consider that URLs are case-sensitive.

This said, lots of users are pestering me for that kind of plugin, so there it is. Have fun breaking the web! :)

## License

Do whatever the hell you want with it.
