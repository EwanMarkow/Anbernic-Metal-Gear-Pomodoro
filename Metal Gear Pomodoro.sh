#!/bin/bash
# Metal Gear Pomodoro — PortMaster launcher (LÖVE 11.5 runtime)

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/metalgearpomodoro"
CONFDIR="$GAMEDIR/conf"
cd "$GAMEDIR"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# One-time move: bring settings and stats over from the old "pomodoro" folder
OLDCONF="/$directory/ports/pomodoro/conf"
if [ -d "$OLDCONF" ] && [ ! -d "$CONFDIR" ]; then
  cp -r "$OLDCONF" "$CONFDIR" && echo "Copied settings and stats from $OLDCONF"
fi
mkdir -p "$CONFDIR"

# LÖVE's save folder (settings.json) goes inside the app folder
export XDG_DATA_HOME="$CONFDIR"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

LOVE_TXT="$controlfolder/runtimes/love_11.5/love.txt"
if [ ! -f "$LOVE_TXT" ]; then
  echo "LOVE 11.5 runtime not found at $LOVE_TXT"
  echo "Install the love_11.5 runtime from PortMaster, then launch again."
  exit 1
fi
source "$LOVE_TXT"

$GPTOKEYB "$LOVE_GPTK" &
pm_platform_helper "$LOVE_BINARY"
$LOVE_RUN "$GAMEDIR/lovegame"

pm_finish
