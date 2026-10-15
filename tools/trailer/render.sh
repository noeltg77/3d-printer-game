#!/usr/bin/env bash
# Builds, renders and encodes the Steam trailer. Run from the repo root:
#
#   tools/trailer/render.sh             # full 1920x1080, 60 fps (about 2.5 hours on an M3 Pro)
#   tools/trailer/render.sh --preview   # half size, few samples (about 20 minutes)
#   tools/trailer/render.sh --encode    # only join frames already rendered
#
# Frames are written one PNG at a time with placeholders, so a stopped render
# carries on where it left off, and two Blender processes can share the work.
# Set BLENDER and FFMPEG if they are elsewhere.
set -euo pipefail

BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
FFMPEG="${FFMPEG:-ffmpeg}"
OUT=tools/trailer/out
MODE="${1:-}"

if [[ "$MODE" == "--preview" ]]; then
	BLEND="$OUT/trailer_preview.blend"; FRAMES="$OUT/preview_frames"; TITLES="$OUT/preview_titles"
	VIDEO="$OUT/print_shop_tycoon_trailer_preview.mp4"; BUILD_ARGS=(-- --preview); SIZE=960:540; CRF=16
else
	BLEND="$OUT/trailer.blend"; FRAMES="$OUT/frames"; TITLES="$OUT/titles"
	VIDEO="$OUT/print_shop_tycoon_trailer.mp4"; BUILD_ARGS=(); SIZE=1920:1080; CRF=14
fi

if [[ "$MODE" != "--encode" ]]; then
	"$BLENDER" --background --factory-startup --python tools/trailer/music.py
	"$BLENDER" --background --factory-startup --python tools/trailer/build_trailer.py ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}
	# Two renders of the picture side by side share the frames between them.
	"$BLENDER" --background "$BLEND" -a > "$OUT/render_a.log" 2>&1 &
	sleep 20
	"$BLENDER" --background "$BLEND" -a > "$OUT/render_b.log" 2>&1 &
	wait
	"$BLENDER" --background "$BLEND" -S titles -a > "$OUT/render_titles.log" 2>&1
fi

# The titles over the picture, a touch more contrast and colour than the
# render gives (the game's own look is crisper), and the soundtrack.
"$FFMPEG" -y -framerate 60 -i "$FRAMES/f_%04d.png" -framerate 60 -i "$TITLES/t_%04d.png" -i "$OUT/soundtrack.wav" \
	-filter_complex "[0:v]scale=$SIZE:flags=lanczos,eq=contrast=1.04:saturation=1.12,format=yuv420p10le[base];[1:v]scale=$SIZE:flags=lanczos[top];[base][top]overlay=format=auto,format=yuv420p[v]" \
	-map "[v]" -map 2:a -c:v libx264 -preset slow -tune animation -crf "$CRF" -profile:v high -pix_fmt yuv420p -r 60 \
	-x264-params "keyint=120:min-keyint=60" -c:a aac -b:a 320k -ar 48000 -shortest -movflags +faststart "$VIDEO"
echo "Wrote $VIDEO"
