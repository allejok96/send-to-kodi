#!/bin/bash

# Required settings
host=
port=
# Optional
#user=
#pass=

show_help()
{
    cat<<EOF
Sends a video URL to Kodi
Usage: send-to-kodi.sh [URL]

If no URL is given, a dialog window is shown (requires zenity).

Supports:
Common file formats (mp4,flv,mp3,jpg and more)
Youtube (requires the Youtube plugin in Kodi)
Manny more sites (requires youtube-dl)

Configuration is done in the head of the script.

Note about youtube-dl support:
If youtube-dl returns more the ONE URL this will fail. Why? Because
I'm too lazy and dumb to figure out how to make it work. So, shame
on me!

EOF
}

error()
{
    type zenity &>/dev/null && zenity zenity --error --text "$*" || echo "$*" 1>&2
    exit 1
}

send_json()
{
    curl ${user:+--user "$user:$pass"} -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"Player.Open","params":{"item":{"file":"'"$1"'"}},"id":1}' http://$host:$port/jsonrpc || error "Failed to send link - is Kodi running?"
}

[[ "$1" = --help ]] && show_help

url="$1"

until [[ $url ]]; do
    url="$(zenity --entry --title "Send to Kodi" --text "Paste an URL to a video here")" || exit
done

# youtube.com
if [[ $url =~ ^https?://(www\.)?youtube\.com/watch\?v= ]]; then
    send_json "plugin://plugin.video.youtube/?action=play_video&videoid=$(sed 's/.*[&?]v=\([a-zA-Z0-9]\+\).*/\1/' <<< "$url")"

# youtu.be
elif [[ $url =~ ^https?://youtu\.be/[a-zA-Z0-9] ]]; then
    send_json "plugin://plugin.video.youtube/?action=play_video&videoid=$(sed 's/^https\?:\/\/youtu\.be\/\([a-zA-Z0-9]\+\).*/\1/' <<< "$url")"

# playable files
elif [[ $url =~ \.(mp4|mkv|mov|avi|flv|wmv|asf|mp3|flac|mka|m4a|aac|ogg|pls|jpg|png|gif|jpeg|tiff)(\?.*)?$ ]]; then
     send_json "$url"

# check URL with youtube-dl
else
    type youtube-dl &>/dev/null || exit
    if new_url="$(youtube-dl -g "$url")"; then
	new_url="$(uniq <<< "$new_url")"
	if [[ $(wc -l <<< "$new_url") -gt 1 ]]; then
	    error "Unable to handle multiple video links (but the site seems to be supported by youtube-dl)"
	else
	    send_json "$new_url"
	fi
    else
	error "No videos found, or site not supported by youtube-dl"
    fi
fi
