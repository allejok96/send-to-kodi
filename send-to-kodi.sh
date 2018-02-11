#!/bin/bash

# Required settings
host=
port=

# Optional login for Kodi
#user=
#pass=

# Settings for netcat (local file)
local_hostname=$(hostname)
local_port=12345



show_help()
{
    cat<<EOF
Sends a video URL to Kodi
Usage: send-to-kodi.sh [URL]

If no URL is given, a dialog window is shown (requires zenity).

Supports:
Common file formats (mp4,flv,mp3,jpg and more)
Youtube (requires the Youtube plugin in Kodi)
Local media streaming (via netcat)
Manny more sites (requires youtube-dl)

Configuration is done in the head of the script.

EOF
}

error()
{
    if type zenity &>/dev/null; then
     	zenity --error --ellipsize --text "$*"
    else
	echo "$*" 1>&2
    fi
    
    exit 1
}

send_json()
{
    curl \
	${user:+--user "$user:$pass"} \
	-X POST \
	-H "Content-Type: application/json" \
	-d '{"jsonrpc":"2.0","method":"Player.Open","params":{"item":{"file":"'"$1"'"}},"id":1}' \
	http://$host:$port/jsonrpc \
	|| error "Failed to send link - is Kodi running?"
}

ytplugin='plugin://plugin.video.youtube/?action=play_video&videoid='

[[ $host && $port ]] || error "Please set host and port in configuration"
[[ "$1" = --help ]] && show_help

# Dialog box?
input="$1"
until [[ $input ]]; do
    input="$(zenity --entry --title "Send to Kodi" --text "Paste a video link here")" || exit
done

if [[ $input =~ ^file:// ]]; then
    # Remove file:// and carrige return (\r) at the end
    input="$(sed 's%^file://%%;s/\r$//' <<< "$input")"
fi

# Get URL for...

# Local media
if [[ -e $input ]]; then
    type nc &>/dev/null || error "netcat required"
    [[ $local_hostname && $local_port ]] || error "Please set local hostname and port in configuration"

    # Start netcat in background and kill it when we exit
    nc -lp $local_port < "$input" &
    trap "kill $!" EXIT
    
    url="tcp://$local_hostname:$local_port"
    
# Youtube
elif [[ $input =~ ^https?://(www\.)?youtube\.com/watch\?v= ]]; then
    url="$ytplugin$(sed 's/.*[&?]v=\([a-zA-Z0-9]\+\).*/\1/' <<< "$input")"
elif [[ $input =~ ^https?://youtu\.be/[a-zA-Z0-9] ]]; then
    url="$ytplugin$(sed 's/^https\?:\/\/youtu\.be\/\([a-zA-Z0-9]\+\).*/\1/' <<< "$input")"
    
# Playable formats
elif [[ $input =~ \.(mp4|mkv|mov|avi|flv|wmv|asf|mp3|flac|mka|m4a|aac|ogg|pls|jpg|png|gif|jpeg|tiff)(\?.*)?$ ]]; then
     url="$input"
     
# Youtube-dl
else
    type youtube-dl &>/dev/null || exit 1
    url="$(youtube-dl -gf best "$input")" || error "No videos found, or site not supported by youtube-dl"
fi

[[ $url ]] && send_json "$url"

# Wait for netcat to exit
wait
# Don't kill netcat
trap - EXIT
