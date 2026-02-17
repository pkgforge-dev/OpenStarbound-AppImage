#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
if [ ${OPENSTARBOUND_INPUT:-1} -eq 1 ]; then
	pacman -Syu --noconfirm sdl3 pipewire-audio glu libdecor
else
	pacman -Syu --noconfirm sdl2-compat sdl3 pipewire-audio glu libdecor
fi
echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Installing AUR package dependencies"
echo "---------------------------------------------------------------"
make-aur-package zenity-rs-bin

echo 'Copying game data to ./AppDir/bin/*'
echo "---------------------------------------------------------------"
mkdir -p ./AppDir/bin/
# Copy game files and debloat it
cp -rv ./game-files/* ./AppDir/bin/
rm -v ./AppDir/bin/goggame* ./AppDir/bin/linux/run-*
rm -rv ./AppDir/bin/mods/
# Move game files to relative path and patch sbinit config to reflect that
mv -v ./AppDir/bin/linux/* ./AppDir/bin/
rm -rv ./AppDir/bin/linux/
sed -i 's|"../|"./|g' ./AppDir/bin/sbinit.config
# Copy libsteam_api to lib dir and copy hooks to fix sbinit.config storage and mods location in the AppImage
cp -v ./AppDir/bin/libsteam_api.so /usr/lib/libsteam_api.so
cp -v ./writable-storage-and-mods.hook ./AppDir/bin/writable-storage-and-mods.hook
cp -v ./launch-starbound-script-instead-of-bin.src.hook ./AppDir/bin/launch-starbound-script-instead-of-bin.src.hook
# Part of the hooks to execute custom sbinit.config
echo '#!/bin/sh

starbound -bootconfig "${XDG_CONFIG_HOME:-$HOME/.config}/starbound/sbinit.config" "${@}"' > ./AppDir/bin/Starbound
echo '#!/bin/sh

starbound_server -bootconfig "${XDG_CONFIG_HOME:-$HOME/.config}/starbound/sbinit.config" "${@}"' > ./AppDir/bin/StarboundServer
chmod +x ./AppDir/bin/Starbound ./AppDir/bin/StarboundServer

if [ ${OPENSTARBOUND_INPUT:-1} -eq 1 ]; then
	echo "Installing OpenStarbound"
	echo "---------------------------------------------------------------"
	cp -rv ./OpenStarbound/* ./AppDir/bin/
	rm -v  ./AppDir/bin/linux/run-*
	mv -v ./AppDir/bin/linux/* ./AppDir/bin/
	rm -rv ./AppDir/bin/linux/
	rm -rv ./AppDir/bin/mods/
	cp -v ./AppDir/bin/libsteam_api.so /usr/lib/libsteam_api.so
	cp -v ./AppDir/bin/libdiscord_game_sdk.so /usr/lib/libdiscord_game_sdk.so
	sed -i 's|"../|"./|g' ./AppDir/bin/sbinit.config
fi
