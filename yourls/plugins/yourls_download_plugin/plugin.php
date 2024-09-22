<?php
/*
Plugin Name: Download Plugin
Plugin URI: https://github.com/krissss/yourls-download-plugin
Description: Download Plugin From Url
Version: 1.0
Author: Kriss
Author URI: https://github.com/krissss/
*/

if (!defined('YOURLS_ABSPATH')) die();

if (!class_exists('ZipArchive')) {
    yourls_add_notice("<b>Download Plugin</b> plugin need <b>zip</b> extension!");
}

yourls_add_action('plugins_loaded', 'kriss_download_plugin_settings');
function kriss_download_plugin_settings()
{
    yourls_register_plugin_page('download_plugin_settings', 'Download Plugin', 'kriss_download_plugin_page');
}

function kriss_download_plugin_page()
{
    $msg = '';

    if (isset($_POST['github_url'])) {
        yourls_verify_nonce('download_plugin_settings');
        list($is, $txt) = kriss_download_plugin();
        $info = $is ? ['txt' => 'success', 'color' => 'green'] : ['text' => 'fail', 'color' => 'red'];
        $msg = "<p style='color: {$info['color']}'>download {$info['txt']}: {$txt}</p>";
    }

    $nonce = yourls_create_nonce('download_plugin_settings');
    echo <<<HTML
        <main>
            <h2>Download Plugin</h2>
            <p><a href="https://github.com/YOURLS/awesome-yourls" target="_blank">plugin list</a></p>
            {$msg}
            <form method="post">
            <input type="hidden" name="nonce" value="$nonce" />
            <p>
                <label>Url</label>
                <input type="text" name="github_url" value="" required />
                <hint>support github, like: <code>https://github.com/krissss/yourls-download-plugin</code></hint>
            </p>
            <p>
                <label>Branch</label>
                <input type="text" name="github_branch" value="master" required />
                <hint>which branch to download</hint>
            </p>
            <p>
                <label>Name</label>
                <input type="text" name="download_name" value="" />
                <hint>optional, zip filename. If empty basename of url will be use</hint>
            </p>
            <p>
                <label>Delete zip after unzip</label>
                <input type="radio" name="delete_after_unzip" value="1" checked />Delete
                <input type="radio" name="delete_after_unzip" value="0" />Keep
            </p>
            <p><input type="submit" value="Download" class="button" /></p>
            </form>
        </main>
HTML;
}

function kriss_download_plugin()
{
    $url = $_POST['github_url'];
    $branch = $_POST['github_branch'];
    $name = $_POST['download_name'];

    // parse url
    if (strpos($url, 'https://github.com/') === 0) {
        list($downloadUrl, $unzipFolderName) = kriss_parse_github_url($url, $branch);
    } else {
        return [false, 'url not support'];
    }

    $downloadName = $name ?: basename($url) . '.zip';
    $filepath = __DIR__ . '/../' . $downloadName;
    $unzipPath = __DIR__ . '/../';
    $unzipFolderName = __DIR__ . '/../' . $unzipFolderName . '/';

    // download file
    if (file_exists($filepath)) {
        return [false, 'file ' . $filepath . ' existed'];
    }
    $content = file_get_contents($downloadUrl);
    file_put_contents($filepath, $content);

    // unzip
    $zip = new ZipArchive();
    $unzipOk = false;
    if ($zip->open($filepath) === true) {
        $zip->extractTo($unzipPath);
        $zip->close();
        $unzipOk = true;
    }

    // auto detect plugin root
    $pluginPath = kriss_auto_detect_plugin_root($unzipFolderName, 'plugin.php');
    if ($pluginPath === false) {
        unlink($filepath);
        return [false, 'no plugin.php find in zip'];
    }
    if ($unzipFolderName . 'plugin.php' !== $pluginPath) {
        copy($pluginPath, $unzipFolderName . 'plugin.php');
    }

    // delete file
    if (isset($_POST['delete_after_unzip']) && $_POST['delete_after_unzip']) {
        unlink($filepath);
    }

    if (!$unzipOk) {
        return [false, 'unzip failed'];
    }

    return [true, $downloadName];
}

function kriss_parse_github_url($url, $branch)
{
    $downloadUrl = "$url/archive/refs/heads/{$branch}.zip";
    $unzipFolderName = basename($url) . '-' . $branch;

    return [$downloadUrl, $unzipFolderName];
}

function kriss_auto_detect_plugin_root($path, $pluginName)
{
    $path = rtrim($path, '/');
    if (file_exists($path . '/'. $pluginName)) {
        return $path . '/'. $pluginName;
    }
    foreach (glob($path . '/*', GLOB_ONLYDIR) as $dir) {
        return kriss_auto_detect_plugin_root($dir, $pluginName);
    }
    return false;
}
