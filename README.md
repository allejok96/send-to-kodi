# Send to Kodi

This is a very simple script that sends a video/sound/image URL from your desktop to Kodi.

It supports common file formats, youtube and has limited support for youtube-dl.

**Usage:**

1. In Kodi, enable *System > Servicies > Web server > Allow remote control via HTTP*

1. Edit the script and add your `host` and `port` in the head of the script, and optionally `user` and `pass`.

1. Run the script, either via the command line:

    ./send-to-kodi.sh https://www.youtube.com/watch?v=1paueaTWFRE

    ./send-to-kodi.sh https://vimeo.com/174312494

1. Or run the script without arguments to get a GUI:

