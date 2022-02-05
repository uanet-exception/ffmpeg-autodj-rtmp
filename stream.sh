#!/usr/bin/env bash

set --;
trap 'test -e "$TITLE_FILE" && rm "$TITLE_FILE"; test -e "$TMP_FILE" && rm "$TMP_FILE"' EXIT;

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
TITLE_FILE="$(mktemp)";
TMP_FILE="$(mktemp)";
VIDEO="$DIR/cassete.gif";
MUSIC_DIR="$DIR/music";
RTMP_SERVERS="[f=flv]rtmp://142.250.184.206/live/radio?access_token=84VzGMZuUrmftDCvnr";

which mbuffer &>/dev/null || { echo "[ERROR] mbuffer not found" 1>&2; exit 1; }
which ffmpeg &>/dev/null || { echo "[ERROR] ffmpeg not found" 1>&2; exit 1; }
which jq &>/dev/null || { echo "[ERROR] jq not found" 1>&2; exit 1; }

while true; do
    EXP_TIME=${1/ */};
    test $# -gt 0 -a "$(date +%s)" -ge "$EXP_TIME" && shift && set -- "$@";

    echo ${1#* } > "$TMP_FILE" && mv "$TMP_FILE" "$TITLE_FILE";

    kill -0 "$(jobs -p | head -n 1)" &> /dev/null && { sleep 1s; continue; } || wait;

    MP3_FILE="$(find "$MUSIC_DIR" -type f -name '*.mp3' | shuf -n 1)";

    SONG_TITLE="$(ffprobe -show_format -print_format json "$MP3_FILE" 2>/dev/null \
        | jq -r '.format | [.tags.artist,.tags.title] | join(" - ")')";
    SONG_LEN="$(ffprobe -show_format -print_format json "$MP3_FILE" 2>/dev/null \
        | jq -r .format.duration | sed 's|\..*||')";

    START_TIME=$(date +%s);
    if test $# -gt 0; then
        LAST_QUEUED="${@: -1}";
        START_TIME=${LAST_QUEUED/ */};
    fi

    set -- "$@" "$(( $START_TIME + $SONG_LEN )) $SONG_TITLE";

    ffmpeg -hide_banner -i "$MP3_FILE" -vn -acodec copy -f mpegts - &
done | mbuffer -q -c -m 20000k | (
    ffmpeg -hide_banner \
        -stream_loop -1 -i "$VIDEO" \
        -err_detect explode \
        -i pipe:0 \
        -map 0:v \
        -map 1:a \
        -acodec libmp3lame \
        -ar 44100 -b:a 128k \
        -pix_fmt yuv420p \
        -profile:v baseline \
        -s 1920x1080 \
        -bufsize 6000k \
        -vb 400k \
        -maxrate 1500k \
        -deinterlace \
        -vcodec libx264 \
        -b:a 256k \
        -preset fast \
        -filter_complex "drawtext=font=monospace:fontcolor=black:x=(w-100-text_w)/2:y=435:fontsize=30:textfile='$TITLE_FILE':reload=1" \
        -g 60 \
        -r 30 \
        -f tee \
        -flvflags no_duration_filesize \
        $RTMP_SERVERS;
)
