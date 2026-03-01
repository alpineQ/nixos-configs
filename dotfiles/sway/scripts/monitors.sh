#!/usr/bin/env bash

MONITOR_OUTPUT=$(swaymsg -t get_outputs | jq -r 'first(.[] | select(.model == "27B2G5")) | .name')
TV_OUTPUT=$(swaymsg -t get_outputs | jq -r 'first(.[] | select(.model == "Beyond TV")) | .name')
if [ -n "$TV_OUTPUT" ]; then
    echo "Monitor: $MONITOR_OUTPUT, TV: $TV_OUTPUT"
    swaymsg output "$TV_OUTPUT" mode 3840x2160 pos 1920 0 scale 3
    #swaymsg output "$TV_OUTPUT" mode 1920x1080 pos 1920 0
    swaymsg output "$TV_OUTPUT" disable 
    swaymsg output "$MONITOR_OUTPUT" mode 1920x1080 pos 0 0
else
    echo "Monitor: $MONITOR_OUTPUT"
    swaymsg output "$MONITOR_OUTPUT" mode 1920x1080 pos 0 0
fi
