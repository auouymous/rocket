#!/bin/sh

function make_texture(){
	NAME=$1 ; shift
	if [[ $1 =~ ^[0-9]+$ ]]; then FRAMES=$1; shift; else FRAMES=''; fi

	[ ! -z "$FRAMES" ] && I=".${NAME}-0.xpm" || I=".${NAME}.xpm"
	O="textures/${NAME}.png"
	echo "[build] $O"
	convert $I -define png:exclude-chunks=date -strip $* $O

	if [ ! -z "$FRAMES" ]; then
		I=".${NAME}-?.xpm"
		O="textures/${NAME}-animated.png"
		echo "[build] $O"
		montage $I -define png:exclude-chunks=date -strip -mode concatenate -tile 1x$FRAMES $* $O
	fi
}

make_texture rocket-item
make_texture rocket-star
make_texture rocket-blueprint
