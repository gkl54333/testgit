#!/bin/bash

# die when an error occurs
set -e



HOUDINI_URL="http://dl.android-x86.org/houdini/7_y/houdini.sfs"
HOUDINI_SO="https://github.com/Rprop/libhoudini/raw/master/4.0.8.45720/system/lib/libhoudini.so"


####################################### blank



# check if script was started with BASH
if [ ! "$(ps -p $$ -oargs= | awk '{print $1}' | grep -E 'bash$')" ]; then
   echo "Please use BASH to start the script!"
	 exit 1
fi

# check if user is root
if [ "$(whoami)" != "root" ]; then
	echo "Sorry, you are not root. Please run with sudo $0"
	exit 1
fi

# check if lzip is installed
if [ ! "$(which lzip)" ]; then
	echo -e "lzip is not installed. Please install lzip.\nExample: sudo apt install lzip"
	exit 1
fi

# check if squashfs-tools are installed
if [ ! "$(which mksquashfs)" ] || [ ! "$(which unsquashfs)" ]; then
	echo -e "squashfs-tools is not installed. Please install squashfs-tools.\nExample: sudo apt install squashfs-tools"
	exit 1
else
	MKSQUASHFS=$(which mksquashfs)
	UNSQUASHFS=$(which unsquashfs)
fi

# check if wget is installed
if [ ! "$(which wget)" ]; then
	echo -e "wget is not installed. Please install wget.\nExample: sudo apt install wget"
	exit 1
else
	WGET=$(which wget)
fi

# check if unzip is installed
if [ ! "$(which unzip)" ]; then
	echo -e "unzip is not installed. Please install unzip.\nExample: sudo apt install unzip"
	exit 1
else
	UNZIP=$(which unzip)
fi

# check if tar is installed
if [ ! "$(which tar)" ]; then
	echo -e "tar is not installed. Please install tar.\nExample: sudo apt install tar"
	exit 1
else
	TAR=$(which tar)
fi

# use sudo if installed
if [ ! "$(which sudo)" ]; then
	SUDO=""
else
	SUDO=$(which sudo)
fi

if [ ! -f "android.img" ]; then
	echo -e "make android.img first!"
	exit 1
fi

if [ -d "squashfs-root" ]; then
	$SUDO rm -rf squashfs-root
fi

$SUDO $UNSQUASHFS android.img



#load houdini and spread it
if [ ! -f ./houdini.sfs ]; then
  $WGET -q --show-progress $HOUDINI_URL
fi
LIBDIR="./squashfs-root/system/lib"
$SUDO $UNSQUASHFS -d $LIBDIR/arm ./houdini.sfs
$SUDO cp -r ./squashfs-root/system/lib/arm/libhoudini.so "$LIBDIR/"

# set processors
ARM_TYPE=",armeabi-v7a,armeabi"
$SUDO sed -i "/^ro.product.cpu.abilist=x86_64,x86/ s/$/${ARM_TYPE}/" "./squashfs-root/system/build.prop"
$SUDO sed -i "/^ro.product.cpu.abilist32=x86/ s/$/${ARM_TYPE}/" "./squashfs-root/system/build.prop"
$SUDO sed -i "/^ro.product.cpu.abilist32=x86/ s/$/${ARM_TYPE}/" "./squashfs-root/system/build.prop"

$SUDO echo "persist.sys.nativebridge=1" >> "./squashfs-root/system/build.prop"
$SUDO echo "ro.dalvik.vm.isa.arm=x86" >> "./squashfs-root/system/build.prop"

$SUDO sed -i "/^ro.dalvik.vm.native.bridge=0/ s/0/libhoudini.so/" "./squashfs-root/default.prop"

# add features
C=$(cat <<-END
  <feature name="android.hardware.touchscreen" />\n
  <feature name="android.hardware.audio.output" />\n
  <feature name="android.hardware.camera" />\n
  <feature name="android.hardware.camera.any" />\n
  <feature name="android.hardware.location" />\n
  <feature name="android.hardware.location.gps" />\n
  <feature name="android.hardware.location.network" />\n
  <feature name="android.hardware.microphone" />\n
  <feature name="android.hardware.screen.portrait" />\n
  <feature name="android.hardware.screen.landscape" />\n
  <feature name="android.hardware.wifi" />\n
  <feature name="android.hardware.bluetooth" />"
END
)

C=$(echo $C | sed 's/\//\\\//g')
C=$(echo $C | sed 's/\"/\\\"/g')
$SUDO sed -i "/<\/permissions>/ s/.*/${C}\n&/" "./squashfs-root/system/etc/permissions/anbox.xml"
# make wifi and bt available
$SUDO sed -i "/<unavailable-feature name=\"android.hardware.wifi\" \/>/d" "./squashfs-root/system/etc/permissions/anbox.xml"
$SUDO sed -i "/<unavailable-feature name=\"android.hardware.bluetooth\" \/>/d" "./squashfs-root/system/etc/permissions/anbox.xml"





