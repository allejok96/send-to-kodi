# Send to Kodi

This is a very simple script that sends a video/sound/image URL from your desktop to Kodi.

![Screenshot of dialog box](https://cloud.githubusercontent.com/assets/7693838/16900025/29b53d9c-4c18-11e6-8a74-e6d88c33e503.png)

* Send video links to Kodi from your desktop.
* No need to install the relevant add-ons in Kodi (unless it's Youtube).
* `youtube-dl` supports sites that may not have an Kodi add-on.
* No support for local files, though.

**Note:** The youtube-dl support is very limited. It will only work if there only is a SINGLE video stream. I'm just too lazy to figure out how to fix this. If you know, please let me know...

## Usage

1. In Kodi, enable *System > Servicies > Web server > Allow remote control via HTTP*.

1. Edit the script and add your `host` and `port` in the head of the script, and optionally `user` and `pass`.

1. Run the script, either via the command line:

        ./send-to-kodi.sh https://vimeo.com/174312494

1. Or run the script without arguments to get a GUI.

## Requirements

- curl
- zenity (for GUI)
- Youtube add-on in Kodi (youtube support)
- youtube-dl (for sites other than youtube, ironically)

## Also check out
- [Firefox extension](https://addons.mozilla.org/en-US/firefox/addon/send-to-xbmc/) supports Youtube and common file formats.
- [Chrome extension](https://chrome.google.com/webstore/detail/play-to-kodi/fncjhcjfnnooidlkijollckpakkebden?hl=en) supports Youtube, Twitch.tv, Hulu, SVTPlay.se, SoundCloud, and much more (requires the relevant addons to be installed in Kodi)
