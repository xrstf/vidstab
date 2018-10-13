#!/bin/bash

function displaytime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

set -e

mkdir -p "$WORKDIR" "$WORKDIR/output"

s3root="s3://$AWS_S3_BUCKET"
if [ ! -z "$AWS_S3_PREFIX" ]; then
  s3root="$s3root/$AWS_S3_PREFIX"
fi

# list files in S3
echo "Listing files in $s3root/..."
files=$(aws s3 ls "$s3root/" | grep -iE '\.(mkv|mp4)$' | awk '{ print $4 }')

# work through the files
for filename in $files; do
  echo "=====[ $filename ]====="

  SECONDS=0
  vidstabtmp=/tmp/transform_vectors.trf
  inputfile="$WORKDIR/$filename"
  outputfile="(echo "$WORKDIR/output/$filename" | sed 's/\.mp4/\.mkv/i')"

  # download it
  echo "Downloading file..."
  aws s3 cp "$s3root/$filename" "$inputfile"

  # analyze it
  echo "Stabilization analysis..."
  ffmpeg2 \
    -hide_banner \
    -loglevel fatal \
    -stats \
    -i "$inputfile" \
    -vf "vidstabdetect=result=$vidstabtmp:$EXTRACT_PARAMS" \
    -f null \
    -

  # stablize video
  echo "Stabilizing/resampling video..."

  # vid.stab
  params="vidstabtransform=input=$tmpfile:$STAB_PARAMS"

  # scale down to 1080p (crop prevents upscaling)
  params="$params,crop=iw:'max(ih,1080)',scale=height=1080"

  # reduce FPS to 30 (interpolate new frames)
  params="$params,framerate=30"

  # let the magic happen
  ffmpeg2 \
    -i "$inputfile" \
    -vf "$params" \
    -vcodec libx264 \
    -preset $X264_PRESET \
    -tune film \
    -crf $X264_CRF \
    -acodec copy \
    -y \
    "$outputfile"

  # upload result to S3
  echo "Uploading result to S3..."
  aws s3 cp "$outputfile" "$s3root/output/$(basename "$outputfile")"

  echo "Deleting local files..."
  rm -f "$inputfile" "$outputfile"

  echo "Processing took $(displaytime $SECONDS)."
done
