# Send to Kodi

![Screenshot of dialog box](https://cloud.githubusercontent.com/assets/7693838/16900025/29b53d9c-4c18-11e6-8a74-e6d88c33e503.png)

* Paste an URL to play it on Kodi.
* Stream files from your computer to Kodi.
* Uses `youtube-dl` to support hundreds of sites.
* MPEG-DASH (high quality video) support.
* No Kodi add-ons required for standard video.

## Usage

1. In Kodi, enable *System > Servicies > Web server > Allow remote control via HTTP*.

1. Add `HOST` and `PORT` to the head of the script, and optionally `USERNAME` and `PASSWORD`.

1. For full funcitonality:
   - Make sure Kodi has `InputStream.Adaptive` installed.
   - Install `python-twisted` and `youtube-dl` on your computer.

1. Run the script with no arguments for a GUI, or from the command line

        ./send-to-kodi.sh https://vimeo.com/174312494

## Optional depencencies

- zenity (GUI)
- youtube-dl (video sites)
- python-twisted (local file share)
- InputStream.Adaptive in Kodi (MPEG-DASH)
- Youtube add-on in Kodi (better youtube support)

## See also

- [Some Firefox extension](https://github.com/dirkjanm/firefox-send-to-xbmc)
- [Some Chrome extension](https://github.com/khloke/play-to-xbmc-chrome)
