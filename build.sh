#!/bin/bash

# If a command fails, make the whole script exit
set -e
# Use return code for any command errors in part of a pipe
set -o pipefail # Bashism

# Default values
TRIANGLE_DIST="triangle"
TRIANGLE_VERSION="5.0"
TRIANGLE_VARIANT="default"
IMAGE_TYPE="live"
TARGET_DIR="$(dirname $0)/images"
TARGET_SUBDIR=""
SUDO="sudo"
VERBOSE=""
DEBUG=""
HOST_ARCH=$(dpkg --print-architecture)

image_name() {
	case "$IMAGE_TYPE" in
		live)
			live_image_name
		;;
		installer)
			installer_image_name
		;;
	esac
}

live_image_name() {
	case "$TRIANGLE_ARCH" in
		i386|amd64|arm64)
			echo "live-image-$TRIANGLE_ARCH.hybrid.iso"
		;;
		armel|armhf)
			echo "live-image-$TRIANGLE_ARCH.img"
		;;
	esac
}

installer_image_name() {
	if [ "$TRIANGLE_VARIANT" = "netinst" ]; then
		echo "architect/images/triangle-$TRIANGLE_VERSION-$TRIANGLE_ARCH-NETINST-1.iso"
	else
		echo "architect/images/triangle-$TRIANGLE_VERSION-$TRIANGLE_ARCH-DVD-1.iso"
	fi
}

target_image_name() {
	local arch=$1

	IMAGE_NAME="$(image_name $arch)"
	IMAGE_EXT="${IMAGE_NAME##*.}"
	if [ "$IMAGE_EXT" = "$IMAGE_NAME" ]; then
		IMAGE_EXT="img"
	fi
	if [ "$IMAGE_TYPE" = "live" ]; then
		if [ "$TRIANGLE_VARIANT" = "default" ]; then
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Triangle-home-${TRIANGLE_VERSION}_$TRIANGLE_ARCH.$IMAGE_EXT"
		else
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Triangle-$TRIANGLE_VARIANT-${TRIANGLE_VERSION}_$TRIANGLE_ARCH.$IMAGE_EXT"
		fi
	else
		if [ "$TRIANGLE_VARIANT" = "default" ]; then
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Triangle-architect-DVD-${TRIANGLE_VERSION}_$TRIANGLE_ARCH.$IMAGE_EXT"
	    elif [ "$TRIANGLE_VARIANT" = "netinst" ]; then
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Triangle-architect-${TRIANGLE_VERSION}_$TRIANGLE_ARCH.$IMAGE_EXT"
		else
			echo "${TARGET_SUBDIR:+$TARGET_SUBDIR/}Triangle-architect-$TRIANGLE_VARIANT-${TRIANGLE_VERSION}_$TRIANGLE_ARCH.$IMAGE_EXT"
		fi
	fi
}

target_build_log() {
	TARGET_IMAGE_NAME=$(target_image_name $1)
	echo ${TARGET_IMAGE_NAME%.*}.log
}

default_version() {
	case "$1" in
		triangle-*)
			echo "${1#triangle-}"
		;;
		*)
			echo "$1"
		;;
	esac
}

failure() {
	echo "Build of $TRIANGLE_DIST/$TRIANGLE_VARIANT/$TRIANGLE_ARCH $IMAGE_TYPE image failed (see build.log for details)" >&2
	echo "Log: $BUILD_LOG" >&2
	exit 2
}

run_and_log() {
	if [ -n "$VERBOSE" ] || [ -n "$DEBUG" ]; then
		echo "RUNNING: $@" >&2
		"$@" 2>&1 | tee -a "$BUILD_LOG"
	else
		"$@" >>"$BUILD_LOG" 2>&1
	fi
	return $?
}

debug() {
	if [ -n "$DEBUG" ]; then
		echo "DEBUG: $*" >&2
	fi
}

clean() {
	debug "Cleaning"

	# Live
	run_and_log $SUDO lb clean --purge

	# Architect
	run_and_log $SUDO rm -rf "$(pwd)/architect/tmp"
	run_and_log $SUDO rm -rf "$(pwd)/architect/debian-cd"
}

print_help() {
	echo "Usage: $0 [<option>...]"
	echo
	for x in $(echo "${BUILD_OPTS_LONG}" | sed 's_,_ _g'); do
		x=$(echo $x | sed 's/:$/ <arg>/')
		echo "  --${x}"
	done
	exit 0
}

# Allowed command line options
. $(dirname $0)/.getopt.sh

BUILD_LOG="$(pwd)/build.log"
debug "BUILD_LOG: $BUILD_LOG"
# Create empty file
: > "$BUILD_LOG"

# Parsing command line options (see .getopt.sh)
temp=$(getopt -o "$BUILD_OPTS_SHORT" -l "$BUILD_OPTS_LONG,get-image-path" -- "$@")
eval set -- "$temp"
while true; do
	case "$1" in
		-d|--distribution) TRIANGLE_DIST="$2"; shift 2; ;;
		-p|--proposed-updates) OPT_pu="1"; shift 1; ;;
		-a|--arch) TRIANGLE_ARCH="$2"; shift 2; ;;
		-v|--verbose) VERBOSE="1"; shift 1; ;;
		-D|--debug) DEBUG="1"; shift 1; ;;
		-s|--salt) shift; ;;
		-h|--help) print_help; ;;
		--installer) IMAGE_TYPE="installer"; shift 1 ;;
		--live) IMAGE_TYPE="live"; shift 1 ;;
		--rootfs) IMAGE_TYPE="rootfs"; shift 1 ;;
		--iot) IMAGE_TYPE="iot"; shift 1 ;;
		--variant) TRIANGLE_VARIANT="$2"; shift 2; ;;
		--version) TRIANGLE_VERSION="$2"; shift 2; ;;
		--subdir) TARGET_SUBDIR="$2"; shift 2; ;;
		--get-image-path) ACTION="get-image-path"; shift 1; ;;
		--clean) ACTION="clean"; shift 1; ;;
		--no-clean) NO_CLEAN="1"; shift 1 ;;
		--) shift; break; ;;
		*) echo "ERROR: Invalid command-line option: $1" >&2; exit 1; ;;
	esac
done

# Set default values
TRIANGLE_ARCH=${TRIANGLE_ARCH:-$HOST_ARCH}
if [ "$TRIANGLE_ARCH" = "x64" ]; then
	TRIANGLE_ARCH="amd64"
elif [ "$TRIANGLE_ARCH" = "x86" ]; then
	TRIANGLE_ARCH="i386"
fi
debug "TRIANGLE_ARCH: $TRIANGLE_ARCH"

if [ -z "$TRIANGLE_VERSION" ]; then
	TRIANGLE_VERSION="$(default_version $TRIANGLE_DIST)"
fi
debug "TRIANGLE_VERSION: $TRIANGLE_VERSION"

# Check parameters
debug "HOST_ARCH: $HOST_ARCH"
if [ "$HOST_ARCH" != "$TRIANGLE_ARCH" ] && [ "$IMAGE_TYPE" != "installer" ]; then
	case "$HOST_ARCH/$TRIANGLE_ARCH" in
		amd64/i386|i386/amd64)
		;;
		*)
			echo "Can't build $TRIANGLE_ARCH image on $HOST_ARCH system." >&2
		;;
	esac
fi

# Build parameters for lb config
TRIANGLE_CONFIG_OPTS="--distribution $TRIANGLE_DIST -- --variant $TRIANGLE_VARIANT --version $TRIANGLE_VERSION"
CODENAME=$TRIANGLE_DIST # for architect/debian-cd
if [ -n "$OPT_pu" ]; then
	TRIANGLE_CONFIG_OPTS="$TRIANGLE_CONFIG_OPTS --proposed-updates"
	TRIANGLE_DIST="$TRIANGLE_DIST+pu"
fi
debug "TRIANGLE_CONFIG_OPTS: $TRIANGLE_CONFIG_OPTS"
debug "CODENAME: $CODENAME"
debug "TRIANGLE_DIST: $TRIANGLE_DIST"

# Set sane PATH (cron seems to lack /sbin/ dirs)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
debug "PATH: $PATH"

if grep -q -e "^ID=debian" -e "^ID_LIKE=debian" /usr/lib/os-release; then
	debug "OS: $( . /usr/lib/os-release && echo $NAME $VERSION )"
elif [ -e /etc/debian_version ]; then
	debug "OS: $( cat /etc/debian_version )"
else
	echo "ERROR: Non Debian-based OS" >&2
fi

debug "IMAGE_TYPE: $IMAGE_TYPE"
case "$IMAGE_TYPE" in
	live)
		if [ ! -d "$(dirname $0)/templates/variant-$TRIANGLE_VARIANT" ]; then
			echo "ERROR: Unknown variant of Triangle live configuration: $TRIANGLE_VARIANT" >&2
		fi

		ver_live_build=$(dpkg-query -f '${Version}' -W live-build)
		if dpkg --compare-versions "$ver_live_build" lt 1:20151215; then
			echo "ERROR: You need live-build (>= 1:20151215), you have $ver_live_build" >&2
			exit 1
		fi
		debug "ver_live_build: $ver_live_build"

		ver_debootstrap=$(dpkg-query -f '${Version}' -W debootstrap)
		if dpkg --compare-versions "$ver_debootstrap" lt "1.0.97"; then
			echo "ERROR: You need debootstrap (>= 1.0.97), you have $ver_debootstrap" >&2
			exit 1
		fi
		debug "ver_debootstrap: $ver_debootstrap"
	;;
	installer)
		if [ ! -d "$(dirname $0)/templates/installer-$TRIANGLE_VARIANT" ]; then
			echo "ERROR: Unknown variant of Triangle installer configuration: $TRIANGLE_VARIANT" >&2
		fi

		ver_debian_cd=$(dpkg-query -f '${Version}' -W debian-cd)
		if dpkg --compare-versions "$ver_debian_cd" lt 3.1.28; then
			echo "ERROR: You need debian-cd (>= 3.1.28), you have $ver_debian_cd" >&2
			exit 1
		fi
		debug "ver_debian_cd: $ver_debian_cd"

		ver_simple_cdd=$(dpkg-query -f '${Version}' -W simple-cdd)
		if dpkg --compare-versions "$ver_simple_cdd" lt 0.6.8; then
			echo "ERROR: You need simple-cdd (>= 0.6.8), you have $ver_simple_cdd" >&2
			exit 1
		fi
		debug "ver_simple_cdd: $ver_simple_cdd"
	;;
	rootfs)
	;;
	iot)
	;;
	*)
		echo "ERROR: Unsupported IMAGE_TYPE selected ($IMAGE_TYPE)" >&2
		exit 1
	;;
esac

# We need root rights at some point
if [ "$(whoami)" != "root" ]; then
	if ! which $SUDO >/dev/null; then
		echo "ERROR: $0 is not run as root and $SUDO is not available" >&2
		exit 1
	fi
else
	SUDO="" # We're already root
fi
debug "SUDO: $SUDO"

IMAGE_NAME="$(image_name $TRIANGLE_ARCH)"
debug "IMAGE_NAME: $IMAGE_NAME"

debug "ACTION: $ACTION"
if [ "$ACTION" = "get-image-path" ]; then
	echo $(target_image_name $TRIANGLE_ARCH)
	exit 0
fi

if [ "$NO_CLEAN" = "" ]; then
	clean
fi
if [ "$ACTION" = "clean" ]; then
	exit 0
fi

cd $(dirname $0)
mkdir -p $TARGET_DIR/$TARGET_SUBDIR

# Don't quit on any errors now
set +e

case "$IMAGE_TYPE" in
	iot)
		HERE=$(pwd)
		cd iot
		./build.sh --version $TRIANGLE_VERSION --edition $TRIANGLE_VARIANT --arch $TRIANGLE_ARCH --verbose yes
		cd $HERE
	;;
	rootfs)
		HERE=$(pwd)
		cd rootfs
		./build.sh $TRIANGLE_VERSION
		cd $HERE
	;;
	live)
		debug "Stage 1/2 - Config"
		run_and_log lb config -a $TRIANGLE_ARCH $TRIANGLE_CONFIG_OPTS "$@"
		[ $? -eq 0 ] || failure

		debug "Stage 2/2 - Build"
		run_and_log $SUDO lb build
		if [ $? -ne 0 ] || [ ! -e $IMAGE_NAME ]; then
			failure
		fi
	;;
	installer)
		# Override some debian-cd environment variables
		export BASEDIR="$(pwd)/architect/debian-cd"
		export ARCHES=$TRIANGLE_ARCH
		export ARCH=$TRIANGLE_ARCH
		export DEBVERSION=$TRIANGLE_VERSION
		debug "BASEDIR: $BASEDIR"
		debug "ARCHES: $ARCHES"
		debug "ARCH: $ARCH"
		debug "DEBVERSION: $DEBVERSION"

		if [ "$TRIANGLE_VARIANT" = "netinst" ]; then
			export DISKTYPE="NETINST"
		else
			export DISKTYPE="BD"
		fi
		debug "DISKTYPE: $DISKTYPE"

		if [ -e .mirror ]; then
			triangle_mirror=$(cat .mirror)
		else
			triangle_mirror=https://trianglesec.github.io/direct/triangle
		fi
		if ! echo "$triangle_mirror" | grep -q '/$'; then
			triangle_mirror="$triangle_mirror/"
		fi
		debug "triangle_mirror: $triangle_mirror"

		debug "Stage 1/2 - File(s)"
		# Setup custom debian-cd to make our changes
		cp -aT /usr/share/debian-cd architect/debian-cd
		ln -s sid architect/debian-cd/data/$CODENAME
		[ $? -eq 0 ] || failure

		# Keep 686-pae udebs as we changed the default from 686
		# to 686-pae in the debian-installer images
		sed -i -e '/686-pae/d' \
			architect/debian-cd/data/$CODENAME/exclude-udebs-i386
		[ $? -eq 0 ] || failure

		# Configure the triangle profile with the packages we want
		grep -v '^#' templates/installer-$TRIANGLE_VARIANT/packages \
			> architect/profiles/triangle.downloads
		[ $? -eq 0 ] || failure

		# Tasksel is required in the mirror for debian-cd
		echo tasksel >> architect/profiles/triangle.downloads
		[ $? -eq 0 ] || failure

		# Grub is the only supported bootloader on arm64
		# so ensure it's on the iso for arm64.
		if [ "$TRIANGLE_ARCH" = "arm64" ]; then
			debug "arm64 GRUB"
			echo "grub-efi-arm64" >> architect/profiles/triangle.downloads
			[ $? -eq 0 ] || failure
		fi

		# Run simple-cdd
		debug "Stage 2/2 - Build"
		cd architect/
		export OMIT_DOC_TOOLS=1
		run_and_log build-simple-cdd \
			--verbose \
			--debug \
			--force-root \
			--conf simple-cdd.conf \
			--dist $CODENAME \
			--debian-mirror $triangle_mirror
		res=$?
		cd ../
		if [ $res -ne 0 ] || [ ! -e $IMAGE_NAME ]; then
			failure
		fi
	;;
esac

# If a command fails, make the whole script exit
set -e

debug "Moving files"
run_and_log mv -f $IMAGE_NAME $TARGET_DIR/$(target_image_name $TRIANGLE_ARCH)
run_and_log mv -f "$BUILD_LOG" $TARGET_DIR/$(target_build_log $TRIANGLE_ARCH)

run_and_log echo -e "\n***\nGENERATED TRIANGLE IMAGE: $TARGET_DIR/$(target_image_name $TRIANGLE_ARCH)\n***"
