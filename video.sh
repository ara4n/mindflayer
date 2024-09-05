#!/bin/bash

ffmpeg -framerate 30 -pattern_type glob -i 'IMG/matrix-*.png' -filter:v "crop=3240:1368:0:0" -c:v libx264 -r 30 -pix_fmt yuv420p -y out.mp4

