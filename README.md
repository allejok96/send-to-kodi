# Send to Kodi

![Screenshot of dialog box](https://user-images.githubusercontent.com/7693838/119225728-d94f1000-bb05-11eb-9ff2-5a32d2974f55.png)

* Paste an URL to play it on Kodi.
* Stream files from your computer to Kodi.
* Uses `yt-dlp` (fork of youtube-dl) to support hundreds of sites.
* MPEG-DASH (high quality video) support.
* No Kodi add-ons required for standard video.

## Installation

1. In Kodi, enable *System > Services > Web server > Allow remote control via HTTP*.

1. Install on your Kodi box:
   - `InputStream.Adaptive` to enable MPEG-DASH support.
   - *Youtube add-on* for better youtube support.

1. Install on your Linux machine:
   - `zenity` to get a GUI.
   - `yt-dlp` to add support for hundreds of video sites.   
   - `python-twisted` to enable local file sharing and MPEG-DASH support.

1. Now you can run it from the command line like so:

       ./send-to-kodi -r kodibox:8080 -u kodi:SomePassword https://vimeo.com/174312494
   
1. For a more polished experience, edit `send-to-kodi.desktop` and add your credentials.
   
1. Copy to system folders:
   
       sudo cp send-to-kodi.sh /usr/local/bin/
       sudo cp send-to-kodi.desktop /usr/share/applications/
