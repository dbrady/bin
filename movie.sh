#!/bin/bash
# install gifsicle: http://www.lcdf.org/gifsicle/
# install ffmpeg

pushd ~/Documents
ffmpeg -i in.mov -s 600x400 -pix_fmt rgb8 -r 10 -f gif - | gifsicle -O2 --delay=10 > $1
popd
