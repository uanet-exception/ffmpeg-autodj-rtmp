#!/usr/bin/env bash

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
    MP3_FILE="$(find "$MUSIC_DIR" -type f -name '*.mp3' | shuf -n 1)";
    ffprobe -show_format -print_format json "$MP3_FILE" 2>/dev/null \
        | jq -r '.format | [.tags.artist,.tags.title] | join(" - ")' > "$TMP_FILE";
    mv "$TMP_FILE" "$TITLE_FILE";
    ffmpeg -hide_banner -nostats -nostdin -i "$MP3_FILE" -vn -acodec copy -f mpegts -;
done | mbuffer -q -c -m 512k | (
    ffmpeg -hide_banner -nostats -nostdin \
        -stream_loop -1 -i "$VIDEO" \
        -err_detect explode \
        -i pipe:0 \
        -map 0:v \
        -map 1:a \
        -acodec libmp3lame \
        -ar 44100 -b:a 128k \
        -pix_fmt yuv420p \
        -profile:v baseline \
        -s 960x540 \
        -bufsize 6000k \
        -vb 400k \
        -maxrate 1500k \
        -deinterlace \
        -vcodec libx264 \
        -preset fast \
        -vsync vfr \
        -filter_complex "drawtext=font=monospace:fontcolor=black:x=(w-100-text_w)/2:y=435:fontsize=30:textfile='$TITLE_FILE':reload=1" \
        -g 50 \
        -r 25 \
        -flags +global_header \
        -f tee \
        -flvflags no_duration_filesize \
        $RTMP_SERVERS;
)
