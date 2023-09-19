#!/bin/bash

# Color variables
resetColor="\e[0m\e[0m"
redColor="\e[0;31m\e[1m"
cyanColor="\e[01;96m\e[1m"
whiteColor="\e[01;37m\e[1m"
greenColor="\e[0;32m\e[1m"
yellowColor="\e[0;33m\e[1m"
dot="${redColor}[${yellowColor}*${redColor}]${resetColor}"

# Check root privileges
[ "$EUID" -ne 0 ] && echo -e "$dot ${yellowColor}Please run with ${redColor}root ${yellowColor}or use ${greenColor}sudo${resetColor} " && exit

ARGUMENT_LIST=(
  "version"
  "edition"
  "device"
  "architecture"
  "user"
  "password"
  "desktop"
  "hostname"
  "verbose"
)

# Read arguments
opts=$(getopt \
  --longoptions "$(printf "%s:," "${ARGUMENT_LIST[@]}")" \
  --name "$(basename "$0")" \
  --options "" \
  -- "$@"
)
eval set --$opts
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
		version=$2
		shift 2
		;;
	--edition)
		edition=$2
		shift 2
		;;
    --device)
    	device=$2
		shift 2
		;;
    --architecture)
		architecture=$2
	    shift 2
		;;
    --user)
		user=$2
	    shift 2
		;;
    --password)
		password=$2
	    shift 2
		;;
    --desktop)
		desktop=$2
	    shift 2
		;;
    --hostname)
		hostname=$2
	    shift 2
		;;
	--verbose)
		verbose=$2
		shift 2
		;;
    *)
      break
      ;;
  esac
done

# Set default config 
[ -z $edition ] && edition=home
[ -z $device ] && device=rpi
[ -z $architecture ] && architecture=arm64
[ -z $user ] && user=pi
[ -z $password ] && password=triangle
[ -z $desktop ] && desktop=no
[ -z $hostname ] && hostname=triangle
[ -z $verbose ] && verbose=no

# source config file
[ -f config.txt ] && source config.txt

# Banner
echo -e "${cyanColor} __        __   __   __  ___     ${cyanColor}     __           ${cyanColor} __               __   ___  __  "
echo -e "${cyanColor}|__)  /\  |__) |__) /  \  |      ${cyanColor}/\  |__)  |\/|    ${cyanColor}|__) |  | | |    |  \ |__  |__) "
echo -e "${cyanColor}|    /~~\ |  \ |  \ \__/  |     ${cyanColor}/~~\ |  \  |  |    ${cyanColor}|__) \__/ | |___ |__/ |___ |  \ \n"
echo -e " ${whiteColor}Device: ${resetColor}Raspberry Pi 3/4"
echo -e " ${whiteColor}Architecture: ${cyanColor}$architecture"
echo -e " ${whiteColor}Triangle Edition: ${cyanColor}$edition"
echo -e " ${whiteColor}Version: ${cyanColor}$version"
#echo -e " ${purpleColor}User & password: ${cyanColor}$user $resetColor- $password"
echo -e " ${whiteColor}User: ${cyanColor}$user"
echo -e " ${whiteColor}Password: ${cyanColor}$password"
echo -e " ${whiteColor}Hostname: ${cyanColor}$hostname"
echo -e " ${whiteColor}Desktop: ${cyanColor}$desktop"
echo -e " ${whiteColor}Verbose: ${cyanColor}$verbose$resetColor\n"

# Create work dirs and delete them if they exists
echo -e "$dot$yellowColor Creating work dirs...$resetColor"
[ -d work_dir ] && rm -rf work_dir
[ -d images ] && rm -rf images
mkdir -m 755 work_dir
mkdir -m 755 images


cat > work_dir/default.conf <<EOM
user="$user"
password="$password"
desktop="$desktop"
edition="$edition"
hostname="$hostname"
EOM

# Copy recipe
echo -e "$dot$yellowColor Copying choosen recipe...$resetColor\n"
cp recipes/$device-$edition-$architecture.yaml work_dir/recipe.yaml

# Build the system

debootstrap --arch=$architecture --components=main,contrib,non-free --include=gnupg2,nano,base-files triangle $edition-$architecture https://trianglesec.github.io/direct/triangle/

mount --bind /dev $edition-$architecture/dev
mount --bind /proc $edition-$architecture/proc
mount --bind /sys $edition-$architecture/sys
mount --bind /run $edition-$architecture/run

export DEBIAN_FRONTEND=noninteractive
chroot $edition-$architecture bash -c "apt update"
chroot $edition-$architecture bash -c "apt -y install triangle-core-lite"
chroot $edition-$architecture bash -c "apt update"
chroot $edition-$architecture bash -c "apt -y install ca-certificates pciutils usbutils iw mdadm parted bash-completion rng-tools5 haveged inxi neofetch htop nload iftop"
chroot $edition-$architecture bash -c "apt -y install openssh-server sudo network-manager cloud-guest-utils ntp locales lshw"
chroot $edition-$architecture bash -c "systemctl enable ntp"
if [ $edition == "home" ] || [ $edition == "security" ]; then
	chroot $edition-$architecture bash -c "apt -y install triangle-interface triangle-desktop-mate firefox-esr abiword chromium- mate-user-guide- pocketsphinx-en-us- libreoffice-help-en-us- mythes-en-us- libreoffice-help-common- espeak-ng-data-"
	chroot $edition-$architecture bash -c "apt -y install anonsurf anonsurf-gtk" || true
fi
if [ $edition == "security" ]; then
	chroot $edition-$architecture bash -c "apt -y install -t triangle-backports triangle-tools-automotive triangle-tools-cloud triangle-tools-infogathering triangle-tools-maintain triangle-tools-password triangle-tools-postexploit triangle-tools-pwn triangle-tools-sniff triangle-tools-vuln triangle-tools-web triangle-tools-wireless mate-user-guide- pocketsphinx-en-us- libreoffice-help-en-us- mythes-en-us- libreoffice-help-common- espeak-ng-data- android-sdk- arduino- chromium- chromium-driver- dradis- exploitdb- ferret- fonts-noto-core- freepats- gcc-avr- gnuradio*- guile-2.2-libs- gvim- imagemagick*- llvm-11-dev- lmodern- minicom- pandoc*- plasma-discover- plasma-discover-common- python-all- python-all-dev- python-mpltoolkits.basemap-data- qttools5-dev-tools- seclists- tex-*- tex-gyre- thunderbird- vim- wine- wine64- xpdf- xpra- termit-"
fi

chroot $edition-$architecture bash -c "dconf compile /etc/dconf/db/local /etc/dconf/db/local.d/" || true
chroot $edition-$architecture bash -c "dconf compile /etc/skel/.config/dconf/user /etc/dconf/db/local.d/" || true
chroot $edition-$architecture bash -c "/usr/share/triangle-menu/update-launchers" || true

umount $edition-$architecture/dev
umount $edition-$architecture/proc
umount $edition-$architecture/sys
umount $edition-$architecture/run

rm -rf $edition-$architecture/var/cache/apt/* $edition-$architecture/var/lib/apt/lists/*
tar czvf images/Triangle-$edition-$device-${version}_${architecture}.tar.gz -C $edition-$architecture .



# Build recipe (system and image)
echo -e "$dot$greenColor Bulding system and image...$resetColor"
if [ $verbose = yes ]; then
	vmdb2 --rootfs-tarball=images/Triangle-$edition-$device-${version}_${architecture}.tar.gz --output images/Triangle-$edition-$device-${version}_${architecture}.img work_dir/recipe.yaml --verbose --log work_dir/build.log
else
	vmdb2 --rootfs-tarball=images/Triangle-$edition-$device-${version}_${architecture}.tar.gz --output images/Triangle-$edition-$device-${version}_${architecture}.img work_dir/recipe.yaml --log work_dir/build.log
fi

# Check construction status
returnValue="$?"
[ "$returnValue" -ne 0 ] && echo -e "$redColor[!] Error, retry$resetColor" && exit

xz --best --extreme images/Triangle-$edition-$device-${version}_${architecture}.img

# # Compress and finalize image
# echo -e "$dot$greenColor Compressing and finalizing image...$resetColor"

# PARTNAME=$(kpartx -f images/Triangle-$edition-$device-${version}_$architecture-orig.img | cut -d ' ' -f 1 | grep p2 | sed -e 's/p2//')
# TEMP=$(mktemp -d)
# kpartx -av images/Triangle-$edition-$device-${version}_$architecture-orig.img
# mount /dev/mapper/${PARTNAME}p2 $TEMP
# USED=$(df --output=used "$TEMP" | sed '1d;s/[^0-9]//g')
# umount $TEMP
# rm -r $TEMP
# kpartx -d images/Triangle-$edition-$device-${version}_$architecture-orig.img
# NEWSIZE=$(echo "$USED/1024+100+260" | bc)
# NEWDATASIZE=$(echo "$USED/1024+94" | bc)

# qemu-img create -f raw images/compr.img ${NEWSIZE}M
# sfdisk --quiet --dump images/Triangle-$edition-$device-${version}_$architecture-orig.img | grep -v img2 | sfdisk --quiet --force images/compr.img
# ENDSECTOR=$(fdisk -l -o end images/compr.img | tail -n 1)
# ENDSECTOR=$(echo "$ENDSECTOR+1" | bc -l)
# fdisk images/compr.img << EOF
# n
# p
# 2
# $ENDSECTOR

# w
# EOF
# readarray rmappings < <(sudo kpartx -asv images/Triangle-$edition-$device-${version}_$architecture-orig.img)
# readarray cmappings < <(sudo kpartx -asv images/compr.img)
# set -- ${rmappings[0]}
# rboot="$3"
# set -- ${cmappings[0]}
# cboot="$3"
# sudo dd if=/dev/mapper/${rboot?} of=/dev/mapper/${cboot?} bs=5M status=progress
# set -- ${rmappings[1]}
# rroot="$3"
# set -- ${cmappings[1]}
# croot="$3"
# e2fsck -y -f /dev/mapper/${rroot?}
# #resize2fs /dev/mapper/${rroot?} ${NEWDATASIZE}M
# e2image -rap /dev/mapper/${rroot?} /dev/mapper/${croot?}
# kpartx -ds images/Triangle-$edition-$device-${version}_$architecture-orig.img
# kpartx -ds images/compr.img
# rm images/Triangle-$edition-$device-${version}_$architecture-orig.img
# mv images/compr.img images/Triangle-$edition-$device-${version}_$architecture.img

# echo -e "\n$dot$greenColor Compressing...$resetColor"
# xz --best --extreme images/Triangle-$edition-$device-${version}_$architecture.img
# echo -e "\n$dot$greenColor All done.$resetColor"
