#!/bin/bash
VERSION=$1
function bootstrap {
	ARCH=$1
	EDITION=triangle
	echo "Building $EDITION-$ARCH"
	rm -r $EDITION-$ARCH/ || true
	debootstrap --arch=$ARCH --components=main,contrib,non-free --include=gnupg2,nano,base-files --exclude=triangle-core $EDITION $EDITION-$ARCH https://trianglesec.github.io/direct/triangle/
	rm -rf $EDITION-$ARCH/var/cache/apt/* $EDITION-$ARCH/var/lib/apt/lists/*
	echo "Customizing $EDITION-$ARCH"
	echo "Done $EDITION-$ARCH"
}


mkdir -p images
for arch in amd64 i386 arm64 armhf; do
    bootstrap $arch
    tar cvfp - triangle-$arch/ | xz -q -c --best --extreme - > images/Triangle-rootfs-${VERSION}_$arch.tar.xz
    rm -rf triangle-$arch
done
