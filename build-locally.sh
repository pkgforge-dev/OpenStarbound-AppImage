#!/bin/sh

set -eu

ANYLINUX_WORKING_DIR="${ANYLINUX_WORKING_DIR:-$PWD}"
ANYLINUX_OUTPUT_DIR="${ANYLINUX_OUTPUT_DIR:-$PWD}"
ANYLINUX_BUILD_DIR="${ANYLINUX_BUILD_DIR:-/tmp/build-offline-anylinux}"
ANYLINUX_ARCH_CONTAINER_URL="${ANYLINUX_ARCH_CONTAINER_URL:-ghcr.io/pkgforge-dev/archlinux}"
ANYLINUX_ARCH_CONTAINER_TAG="${ANYLINUX_ARCH_CONTAINER_TAG:-latest}"
ANYLINUX_SETUP_URL="${ANYLINUX_SETUP_URL:-https://raw.githubusercontent.com/pkgforge-dev/anylinux-setup-action/refs/heads/main/action.yml}"
ANYLINUX_SETUP_ACTION="${ANYLINUX_BUILD_DIR}/anylinux-setup-action.yml"
ANYLINUX_GET_DEPENDENCIES="${ANYLINUX_GET_DEPENDENCIES:-$ANYLINUX_WORKING_DIR/get-dependencies.sh}"
ANYLINUX_MAKE_APPIMAGE="${ANYLINUX_MAKE_APPIMAGE:-$ANYLINUX_WORKING_DIR/make-appimage.sh}"
ANYLINUX_CONTAINER_CLEANUP="${ANYLINUX_CONTAINER_CLEANUP:-0}"
OPENSTARBOUND="${OPENSTARBOUND:-1}"
OPENSTARBOUND_VERSION="${OPENSTARBOUND_VERSION:-0.0.0}"
STARBOUND_VERSION="${STARBOUND_VERSION:-1.4.4}"

if command -v podman 1>/dev/null; then
	cont_runner="podman"
elif command -v docker 1>/dev/null; then
	cont_runner="docker"
else
	echo "ERROR: This script requires a container runner like 'podman' or 'docker' to work, exiting"
	exit 1
fi

if ! command -v awk 1>/dev/null; then
	echo "ERROR: This script requires 'awk' to be installed for parsing the anylinux setup container action, exiting"
	exit 1
fi

if ! command -v wget 1>/dev/null && ! command -v curl 1>/dev/null; then
	echo "ERROR: This script requires 'wget' or 'curl' to be installed for downloading stuff, exiting"
	exit 1
fi

_download() {
	if command -v wget 1>/dev/null; then
		DOWNLOAD_CMD="wget -qO"
	elif command -v curl 1>/dev/null; then
		DOWNLOAD_CMD="curl -Lso"
	fi
	COUNT=0
	while [ "$COUNT" -lt 5 ]; do
		if $DOWNLOAD_CMD "$@"; then
			return 0
		fi
		echo "Download failed! Trying again..."
		COUNT=$((COUNT + 1))
		sleep 5
	done
	echo "Failed to download 5 times"
	return 1
}

mkdir -p "$ANYLINUX_BUILD_DIR"

_download "$ANYLINUX_SETUP_ACTION" "$ANYLINUX_SETUP_URL"
ANYLINUX_SETUP_EXTRACT=$(awk 'BEGIN{min=99999} /^\s*run:\s*\|/{c=1; next} c{ if($0==""){ ++n; a[n]=""; next } if($0 ~ /^[[:space:]]+/){ ++n; a[n]=$0; match($0,/[^[:space:]]/); if(RSTART){ lead=RSTART-1; if(lead<min)min=lead } } else exit } END{ if(n==0) exit 1; for(i=1;i<=n;i++){ if(a[i]=="") print ""; else { match(a[i],/[^[:space:]]/); if(RSTART) print substr(a[i],min+1); else print "" } } }' ${ANYLINUX_SETUP_ACTION})
ANYLINUX_SETUP_SCRIPT="$(echo '#!/bin/sh' && echo && echo "$ANYLINUX_SETUP_EXTRACT")"
ANYLINUX_SETUP="${ANYLINUX_BUILD_DIR}/anylinux-setup.sh"
echo "$ANYLINUX_SETUP_SCRIPT" > "$ANYLINUX_SETUP"

$cont_runner run --rm \
    -v "$ANYLINUX_WORKING_DIR":"$ANYLINUX_WORKING_DIR":Z \
    -v "$ANYLINUX_OUTPUT_DIR":"$ANYLINUX_OUTPUT_DIR":Z \
    -v "$ANYLINUX_BUILD_DIR":"$ANYLINUX_BUILD_DIR":Z \
    -w "$ANYLINUX_WORKING_DIR" \
    "$ANYLINUX_ARCH_CONTAINER_URL":"$ANYLINUX_ARCH_CONTAINER_TAG" \
     sh -c \
    "sh \"$ANYLINUX_SETUP\" && OPENSTARBOUND_INPUT=$OPENSTARBOUND sh \"$ANYLINUX_GET_DEPENDENCIES\" && OPENSTARBOUND_INPUT=$OPENSTARBOUND OPENSTARBOUND_VERSION_INPUT=$OPENSTARBOUND_VERSION STARBOUND_VERSION_INPUT=$STARBOUND_VERSION sh \"$ANYLINUX_MAKE_APPIMAGE\""

if [ $ANYLINUX_CONTAINER_CLEANUP -eq 1 ]; then
	$cont_runner rmi -f "$ANYLINUX_ARCH_CONTAINER_URL":"$ANYLINUX_ARCH_CONTAINER_TAG"
fi

rm -rf "$ANYLINUX_BUILD_DIR"
