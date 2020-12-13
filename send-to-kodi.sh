#!/bin/bash

# Kodi settings (required)
HOST=
PORT=

# Login (optional)
USERNAME=
PASSWORD=

# Set to 1 to use Kodi's youtube addon instead of youtube-dl
KODI_YOUTUBE=0

# Local file sharing settings
DOWNLOAD_DIR=~
HTTP_PORT=8080

# Just some internal global variables
GUI=1
HTTP_URL="http://$HOSTNAME:$HTTP_PORT/media"
TWISTED_PATH="$(type -p twist || type -p twist3)"
TMP_FILE=  # Name of downloaded video
TMP_DIR=  # Webserver working directory


show_help()
{
    cat<<EOF
Send a video or URL to Kodi
Usage: send-to-kodi.sh [URL]

Run without arguments to get a GUI. Configuration is done in the head of the script. 

Optional dependencies:
  zenity: dialog boxes
  youtube-dl: support for hunderds of sites
  python-twisted: local media
  Kodi's Youtube addon
EOF
}


# Show a error dialog or message
# args: MESSAGE
error()
{
    if ((GUI)); then
        zenity --error --ellipsize --text "$1"
    else
        printf '\n%s\n' "$1" >&2
    fi
    
    exit 1
}


# Show a question dialog or prompt
# args: MESSAGE
question()
{
    if ((GUI)); then
        zenity --question --ellipsize --text "$1"
    else
        printf '\n%s [y/N] ' "$1" >&2
        read
        [[ $REPLY =~ y|Y ]]
    fi
}


# Download using youtube-dl and maybe show progress bar
# args: URL
download_and_serve()
{
    echo "Getting video title..." >&2
    TMP_FILE="$(youtube-dl --get-filename "$1")"
    file="${DOWNLOAD_DIR:?}/$TMP_FILE"
    
    echo "Downloading video..." >&2
    if ((GUI)); then
        # Filter out the percentage but only 2 digits, never print 100 as it will kill zenity
        zenity --progress --auto-close --text "Downloading video..." < <(youtube-dl -o "$file" --newline "$1" | sed -Eun 's/.* ([0-9][0-9]?)\.[0-9]%.*/\1/p') || exit
    else
        youtube-dl -o "$file" "$1"
    fi

    # Sometimes youtube-dl changes the filename from mp4 to mkv
    if [[ ! -f $file ]]; then
        file="${file%.*}.mkv"
        TMP_FILE="${TMP_FILE%.*}.mkv"
        [[ -f $file ]] || error "Download failed"
    fi
    
    serve "$file"
}


# Start webserver in a background process
# args: FILE
serve()
{
    # Kodi is a request monster which will kill most of these:
    # https://unix.stackexchange.com/questions/32182/simple-command-line-http-server
    # 1. netcat won't work because Kodi will try two GET requests at the same time
    # 2. Python http.server raises BrokenPipeError sometimes with big files,
    #    and also some other error because Kodi keeps breaking the connection
    # 3. Twisted has worked so far for me, but it's a bit fat, I know
    
    [[ $TWISTED_PATH ]] || error "python-twisted is not installed"
    
    # Prepare a directory
    TMP_DIR="$(mktemp -d /tmp/send-to-kodi-XXXX)" || error "Failed to create shared directory"
    if [[ $1 ]]; then
        ln -s "$(realpath "$1")" "$TMP_DIR/media" || error "Failed to write to shared directory"
    fi
    
    echo "Starting webserver..." >&2
    if ((GUI)); then
        # Start server in subshell and send input to zenity just to let it know it's still running
        zenity --progress --pulsate --text "HTTP file share is active..." < <("$TWISTED_PATH" web --path "$TMP_DIR" --listen "tcp:$HTTP_PORT") &
    else
        "$TWISTED_PATH" web --path "$TMP_DIR" --listen "tcp:$HTTP_PORT" &
    fi
    
    # Give it a few secs to start up
    sleep 3s
}


# The EXIT trap
cleanup()
{
    [[ -L $TMP_DIR/media ]] && rm "${TMP_DIR:?}/media"
    [[ -f $TMP_DIR/media.strm ]] && rm "${TMP_DIR:?}/media.strm"
    [[ -d $TMP_DIR ]] && rmdir "$TMP_DIR"
    [[ -f $DOWNLOAD_DIR/$TMP_FILE ]] && question "Delete $TMP_FILE?" && rm "$DOWNLOAD_DIR/$TMP_FILE"
    kill 0
}


### Beginning of script


[[ $HOST && $PORT ]] || error "Please specify HOST and PORT at the top of the script"
[[ "$1" = --help ]] && show_help

trap 'cleanup' EXIT

# Optional GUI
if [[ $1 ]]; then
    input="$1"
    GUI=0
else
    input="$(zenity --entry --title "Send to Kodi" --text "Paste an URL or press OK to select a file")" || exit
    [[ $input ]] || input="$(zenity --file-selection)" || exit
fi


# Local file
if [[ -f $input ]]; then
    serve "$input"
    url="$HTTP_URL"

# Formats supported by Kodi
elif [[ $input =~ \.(mp4|mkv|mov|avi|flv|wmv|asf|mp3|flac|mka|m4a|aac|ogg|pls|jpg|png|gif|jpeg|tiff)(\?.*)?$ ]]; then
     url="$input"
     
# youtube.com / youtu.be
elif [[ KODI_YOUTUBE == 1 && $input =~ ^https?://(www\.)?youtu(\.be/|be\.com/watch\?v=) ]]; then
    id="$(sed -E 's%.*(youtu\.be/|[&?]v=)([a-zA-Z0-9_-]+).*%\2%' <<< "$input")"
    url="plugin://plugin.video.youtube/?action=play_video&videoid=$id"

# youtube-dl
else
    # youtube-dl -g may output different kinds of URL's:
    #
    # 1. Single video URL
    #    This can be played by Kodi directly, most of the time.
    #    Sometimes this will be an MPD and we'll have to do step 3.
    #
    # 2. Video URL + Audio URL
    #    This needs downloading and muxing, which youtube-dl will do for us.
    #    Kodi can do that natively, but only for local media.
    #    Only when an audio file has the same name as a video file.
    #    It doesn't work for STRM files...
    #
    #    If only... Player.Open {"file":"http://video.mp4", "ext_audio":"http://audio.mp3"}
    #
    # 3. MPD + same MPD
    #    Kodi supports MPD playback with InputStream.Adaptive.
    #    Only way to trigger that is through an addon, or by using #KODIPROP in a STRM file.
    #    In my testing the two MPD's provided by youtube-dl have been identical.
    #
    #    If only... Player.Open {"file":"http://playlist.mpd"}
    #
    # 4. Video MPD + Audio MPD (?)
    #    IF this exists, we have to do step 2.
    #
    # 5. ISM or HLS (?)
    #    Kodi has support for these, the same way 3. is done, but I haven't implemented it
    #    in the script, because I have no sites to test on.
    #

    type youtube-dl &>/dev/null || error "youtube-dl not installed"
    dash='^[^?]*\.mpd(\?|$)'
    
    echo "Looking for best video..." >&2
    best="$(youtube-dl -g "$input")" || error "No videos found or site not supported by youtube-dl"
    echo "Looking for compatible video..." >&2
    url="$(youtube-dl -gf best "$input")"
    
    # There is a better URL (but it will need some pre-processing)
    if [[ $url != $best ]]; then
        video="$(head -n1 <<< "$best" | tail -n1)"
        audio="$(head -n2 <<< "$best" | tail -n1)"
        
        # MPEG-DASH question
        if [[ $video == $audio && $video =~ $dash ]]; then
            [[ -z $url || $url =~ $dash ]] || question "Use MPEG-DASH for better quality?" && url="$video"
            
        # Download with youtube-dl
        elif [[ -z $url ]] || question "Download for better quality?"; then
            download_and_serve "$input"
            url="$HTTP_URL"
        fi
    fi
    
    # MPEG-DASH
    # Do this down here since both $url and $best can be a MPD
    if [[ $url =~ $dash ]]; then
        serve  # create TMP_DIR
        (echo '#KODIPROP:inputstreamaddon=inputstream.adaptive'
        echo '#KODIPROP:inputstream.adaptive.manifest_type=mpd'
        echo "$video") > "$TMP_DIR/media.strm"
        url="$HTTP_URL.strm"
    fi
    
fi


echo "Requesting to play: $url" >&2

curl -X POST -H "Content-Type: application/json" \
     ${USERNAME:+--user "$USERNAME:$PASSWORD"} \
     -d '{"jsonrpc":"2.0","method":"Player.Open","params":{"item":{"file":"'"$url"'"}},"id":1}' \
     http://$HOST:$PORT/jsonrpc \
|| error "Failed to send - is Kodi running?"
    
echo


# Maybe wait for server (trap will kill it on EXIT)
wait
