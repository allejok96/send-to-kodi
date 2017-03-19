# Send to Kodi

![Screenshot of dialog box](https://cloud.githubusercontent.com/assets/7693838/16900025/29b53d9c-4c18-11e6-8a74-e6d88c33e503.png)

* Paste a video URL to play it on Kodi.
* No Kodi add-ons required (except for Youtube).
* `youtube-dl` supports a bunch of sites.
* Stream local files from computer to Kodi.

## Usage

1. In Kodi, enable *System > Servicies > Web server > Allow remote control via HTTP*.

1. Add `host` and `port` to the head of the script, and optionally `user` and `pass`.

1. Run the script with no arguments for a GUI, or from the command line

        ./send-to-kodi.sh https://vimeo.com/174312494

## Requirements

- curl
- zenity (for GUI)
- Youtube add-on in Kodi (youtube support)
- youtube-dl (for sites other than youtube, ironically)
- netcat (local streaming)

## Inspired by

- [Firefox extension](https://addons.mozilla.org/en-US/firefox/addon/send-to-xbmc/) supports Youtube and common file formats.
- [Chrome extension](https://chrome.google.com/webstore/detail/play-to-kodi/fncjhcjfnnooidlkijollckpakkebden?hl=en) supports Youtube, Twitch.tv, Hulu, SVTPlay.se, SoundCloud, and much more (requires the relevant addons to be installed in Kodi)
- [@facmachado's send2kodi script](https://github.com/facmachado/send2kodi)