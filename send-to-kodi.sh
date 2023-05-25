#!/bin/bash

show_help()
{
    cat<<EOF >&2
Usage: send-to-kodi.sh [options] -r HOST:PORT [URL|FILE]

Send a local or online video to Kodi. Run without URL to get a GUI.
In the GUI, you may prepend an URL with ! to disable resolving (like -x).

Options:
  -d DIRECTORY           Temporary download directory for high quality streaming
  -l PORT                Local port number used for file sharing (default 8080)
  -r HOST:PORT           Kodi remote address
  -u USERNAME:PASSWORD   Kodi login credentials
  -x                     Do not try to resolve URL, just send it
  -y                     Use Kodi's youtube addon instead of youtube-dl

Environment variables:
  TWISTED_PATH           Path to python-twisted webserver
  YOUTUBE_DL             Path to youtube-dl (or one of its forks)

Optional dependencies:
  zenity                 Graphical interface
  youtube-dl             Support for hundreds of sites
  python-twisted         Local media sharing (or high quality download)
EOF
}


# Show a error dialog or message
# args: MESSAGE
error()
{
    if ((GUI)); then
        zenity --error --ellipsize --text "$1"
    else
        printf '%s\n' "$1" >&2
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
        printf '%s [y/N] ' "$1" >&2
        read
        [[ $REPLY =~ y|Y ]]
    fi
}


# Run youtube-dl or whatever we find
# args: *
ytdl()
{
		[[ $YOUTUBE_DL ]] || YOUTUBE_DL="$(type -p youtube-dlp || type -p youtube-dl)"
		[[ $YOUTUBE_DL ]] || error "youtube-dl (or youtube-dlp) is not installed"
		"$YOUTUBE_DL" "$@"
}


# Download using youtube-dl and maybe show progress bar
# args: URL
download_and_serve()
{
    echo "Getting video title..." >&2
    TMP_FILE="$(ytdl --get-filename "$1")"
    file="${DOWNLOAD_DIR:?}/$TMP_FILE"
    
    echo "Downloading video..." >&2
    if ((GUI)); then
        # Filter out the percentage but only 2 digits, never print 100 as it will kill zenity
        zenity --progress --auto-close --text "Downloading video..." < <(ytdl -o "$file" --newline "$1" | sed -Eun 's/.* ([0-9][0-9]?)\.[0-9]%.*/\1/p') || exit
    else
        ytdl -o "$file" "$1"
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

    [[ $TWISTED_PATH ]] || TWISTED_PATH="$(type -p twist || type -p twist3)"
    [[ $TWISTED_PATH ]] || error "python-twisted is not installed"
    
    # Prepare a directory
    TMP_DIR="$(mktemp -d /tmp/send-to-kodi-XXXX)" || error "Failed to create shared directory"
    if [[ $1 ]]; then
        ln -s "$(realpath "$1")" "$TMP_DIR/media" || error "Failed to write to shared directory"
    fi
    
    echo "Starting webserver..." >&2
    "$TWISTED_PATH" web --path "$TMP_DIR" --listen "tcp:$SHARE_PORT" & TWISTED_PID=$!
    
    # Give it a few secs to start up
    sleep 3s
}


# The EXIT trap
cleanup()
{
    if [[ -d $TMP_DIR ]]; then
        [[ -L $TMP_DIR/media ]] && rm "$TMP_DIR/media"
        [[ -f $TMP_DIR/media.strm ]] && rm "$TMP_DIR/media.strm"
        rmdir "$TMP_DIR"
    fi
    if [[ -d $DOWNLOAD_DIR && -f $DOWNLOAD_DIR/$TMP_FILE ]]; then
        question "Delete $TMP_FILE?" && rm "$DOWNLOAD_DIR/$TMP_FILE"
    fi
    [[ $TWISTED_PID ]] && kill "$TWISTED_PID"
}


### Beginning of script

shopt -s nocasematch

GUI=1
DOWNLOAD_DIR=.
KODI_YOUTUBE=0
SEND_RAW=0
SHARE_PORT=8080

while [[ $* ]]; do
    case "$1" in
        -h|--help) show_help;    exit  ;;
        -d) DOWNLOAD_DIR="$2";   shift ;;
        -l) SHARE_PORT="$2";     shift ;;
        -r) REMOTE="$2";         shift ;;
        -u) LOGIN="$2";          shift ;;
        -x) SEND_RAW=1;                ;;
        -y) KODI_YOUTUBE=1;            ;;
        -*) error "Unknown flag: $1"   ;;
         *) INPUT="$1"; GUI=0          ;;
    esac
    shift
done

[[ $REMOTE ]] || error "No hostname specified, see --help"

if ((GUI)); then
    INPUT="$(zenity --entry --title "Send to Kodi" --text "Paste an URL or press OK to select a file")" || exit
    [[ $INPUT ]] || INPUT="$(zenity --file-selection)" || exit
fi


trap 'cleanup' EXIT

# Don't try to resolve
if ((SEND_RAW)); then
    url="$INPUT"

elif [[ $INPUT =~ ^! ]]; then
    url="${INPUT:1}"

# Local file
elif [[ -f $INPUT ]]; then
    serve "$INPUT"
    url="http://$HOSTNAME:$SHARE_PORT/media"

# Other protocols
elif ! [[ $INPUT =~ ^https?:// ]]; then
     url="$INPUT"

# Formats supported by Kodi
elif [[ $INPUT =~ \.(mp[g34]|mk[va]|mov|avi|flv|wmv|asf|flac|m4[av]|aac|og[gm]|pls|jpe?g|png|gif|jpe?g|tiff|m3u8?)(\?.*)?$ ]]; then
     url="$INPUT"
     
# youtube.com / youtu.be
elif ((KODI_YOUTUBE)) && [[ $INPUT =~ ^https?://(www\.)?youtu(\.be/|be\.com/watch\?v=) ]]; then
    id="$(sed -E 's%.*(youtu\.be/|[&?]v=)([a-zA-Z0-9_-]+).*%\2%' <<< "$INPUT")"
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

    dash='^[^?]*\.mpd(\?|$)'
    
    echo "Looking for best video..." >&2
    best="$(ytdl -g "$INPUT")" || error "No videos found or site not supported by youtube-dl"
    echo "Looking for compatible video..." >&2
    url="$(ytdl -gf best "$INPUT")"
    
    # There is a better URL (but it will need some pre-processing)
    if [[ $url != "$best" ]]; then
        video="$(head -n1 <<< "$best" | tail -n1)"
        audio="$(head -n2 <<< "$best" | tail -n1)"
        
        # MPEG-DASH question
        if [[ $video == "$audio" && $video =~ $dash ]]; then
            [[ -z $url || $url =~ $dash ]] || question "Use MPEG-DASH for better quality?" && url="$video"
            
        # Download with youtube-dl
        elif [[ -z $url ]] || question "Download for better quality?"; then
            download_and_serve "$INPUT"
            url="http://$HOSTNAME:$SHARE_PORT/media"
        fi
    fi
    
    # MPEG-DASH
    # Do this down here since both $url and $best can be a MPD
    if [[ $url =~ $dash ]]; then
        serve  # create TMP_DIR
        (echo '#KODIPROP:inputstream=inputstream.adaptive'
        echo '#KODIPROP:inputstream.adaptive.manifest_type=mpd'
        echo "$video") > "$TMP_DIR/media.strm"
        url="http://$HOSTNAME:$SHARE_PORT/media.strm"
    fi
    
fi

echo "Requesting to play: $url" >&2

response="$(curl -X POST -H 'Content-Type: application/json' \
            ${LOGIN:+--user "$LOGIN"} \
            -d '{"jsonrpc":"2.0","method":"Player.Open","params":{"item":{"file":"'"$url"'"}},"id":1}' \
            "http://$REMOTE/jsonrpc" 2>/dev/null)"

[[ $? ]] || error "Failed to send - is Kodi running?"
[[ $response ]] || error "No response from Kodi - maybe wrong login?"
[[ $response == *'"result":"OK"'* ]] || error "Kodi response: $response"
echo "Response: OK" >&2

# Maybe wait for server (trap will kill it on EXIT)
if [[ $TWISTED_PID ]]; then
    if ((GUI)); then
        zenity --info --no-wrap --text "File share active" --ok-label "Stop"
    else
        echo "File share active, press Ctrl+C to abort..." >&2
        wait
    fi
fi
