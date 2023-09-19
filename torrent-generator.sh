#!/bin/bash
ISOFILE=$2
PATH=$1
echo "creating torrent for $ISOFILE"

/usr/bin/mktorrent \
-a https://tracker.triangle.sh/announce,https://wolf.trianglesec.io/announce \
-a https://ashrise.com:443/phoenix/announce \
-a http://tracker.bt4g.com:2095/announce \
-a http://ipv4announce.sktorrent.eu:6969/announce \
-a udp://bt1.archive.org:6969/announce \
-a udp://tracker.opentrackr.org:1337/announce \
-a udp://open.demonii.com:1337/announce \
-a udp://tracker.ccc.de:80/announce \
-a udp://tracker.openbittorrent.com:80/announce \
-a udp://tracker.publicbt.com:80/announce \
-a udp://ipv4.tracker.harry.lu:80/announce,udp://ipv6.tracker.harry.lu:80/announce \
-a udp://tracker.coppersurfer.tk:6969/announce \
-a udp://tracker.moeking.me:6969/announce \
-c "Triangle Security OS official torrent - don't seed it if an updated version is available. for security reasons we don't want old releases to be seeded." \
-w \
https://ftp-stud.hs-esslingen.de/Mirrors/archive.trianglesec.org/$PATH/$ISOFILE,\
https://ftp.halifax.rwth-aachen.de/trianglesec/$PATH/$ISOFILE,\
https://ftp.nluug.nl/os/Linux/distr/triangle/$PATH/$ISOFILE,\
https://mirrors.dotsrc.org/triangle/$PATH/$ISOFILE,\
http://matojo.unizar.es/triangle/$PATH/$ISOFILE,\
https://ftp.cc.uoc.gr/mirrors/linux/triangle/$PATH/$ISOFILE,\
https://trianglesec.volia.net/$PATH/$ISOFILE,\
https://mirrors.up.pt/triangle/$PATH/$ISOFILE,\
https://mirror.yandex.ru/mirrors/$PATH/$ISOFILE,\
https://triangle.mirror.garr.it/mirrors/triangle/$PATH/$ISOFILE,\
http://mirrors.mit.edu/triangle/$PATH/$ISOFILE,\
http://sft.if.usp.br/triangle/$PATH/$ISOFILE,\
https://mirror.clarkson.edu/triangle/$PATH/$ISOFILE,\
https://mirror.kku.ac.th/triangle/$PATH/$ISOFILE,\
https://mirror.cedia.org.ec/triangle/$PATH/$ISOFILE,\
https://mirror.ueb.edu.ec/triangle/$PATH/$ISOFILE,\
https://mirror.0x.sg/triangle/$PATH/$ISOFILE,\
https://mirrors.tuna.tsinghua.edu.cn/triangle/$PATH/$ISOFILE,\
https://mirrors.ustc.edu.cn/triangle/$PATH/$ISOFILE,\
https://mirrors.shu.edu.cn/triangle/$PATH/$ISOFILE,\
http://free.nchc.org.tw/triangle/$PATH/$ISOFILE,\
https://mirrors.ocf.berkeley.edu/triangle/$PATH/$ISOFILE,\
http://mirror.lagoon.nc/pub/triangle/$PATH/$ISOFILE,\
https://mirror.triangle.sh/triangle/$PATH/$ISOFILE,\
https://mirrors.aliyun.com/triangle/,\
\
https://master.dl.sourceforge.net/project/trianglesecurity/$PATH/$ISOFILE,\
 -l 20 $ISOFILE
