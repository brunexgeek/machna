#!/bin/bash

if [ "$1" == "debug" ]; then
	EXTRA="-s -S"
fi

/usr/bin/qemu $EXTRA -boot d -m 32 -cdrom  'build/machina.iso' -hda 'build/disk0.img' -net none -localtime -k pt-br -serial stdio
