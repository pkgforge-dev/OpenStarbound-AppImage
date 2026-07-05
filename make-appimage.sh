#!/bin/sh

set -eu

ARCH=$(uname -m)
if [ ${OPENSTARBOUND_INPUT:-1} -eq 1 ]; then
	VERSION="${OPENSTARBOUND_VERSION_INPUT:-0.0.0}"
	APPNAME=OpenStarbound
else
	VERSION="${STARBOUND_VERSION_INPUT:-1.4.4}"
	APPNAME=Starbound
fi
export ARCH VERSION APPNAME
export OUTPATH=./dist
export DESKTOP=starbound.desktop
export ICON=starbound.png
export DEPLOY_OPENGL=1
export DEPLOY_SDL=1
export DEPLOY_PIPEWIRE=1
export MAIN_BIN=starbound
export STARTUPWMCLASS=starbound

# Deploy dependencies
quick-sharun ./AppDir/bin/starbound* \
             /usr/bin/zenity

# Set Starbound's default sbinit.config for server too in root dir, as server does not accept arguments at all for some reason
cat << 'EOF' > ./AppDir/bin/sbinit.config
{
  "assetDirectories" : [
    "./assets/",
    "${XDG_DATA_HOME:-$HOME/.local/share}/starbound/mods/"
  ],

  "storageDirectory" : "${XDG_DATA_HOME:-$HOME/.local/share}/starbound/storage/",
  "logDirectory" : "${XDG_DATA_HOME:-$HOME/.local/share}/starbound/logs/"
}
EOF
echo 'SHARUN_WORKING_DIR=${SHARUN_DIR}/bin' >> ./AppDir/.env

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the app normally quits before that time
# then skip this or check if some flag can be passed that makes it stay open
#quick-sharun --test ./dist/*.AppImage
