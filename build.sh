#!/bin/bash
BUILD_FOLDER=build
VERSION=$(cat core/banner.go | grep Version | cut -d '"' -f 2)

GO_BUILD_FLAGS=--ldflags '-linkmode external -extldflags "-static -s -w"' -v
CROSS_LIB=/tmp/libpcap-1.8.1/libpcap.a

bin_dep() {
    BIN=$1
    which $BIN > /dev/null || { echo "@ Dependency $BIN not found !"; exit 1; }
}

host_dep() {
    HOST=$1
    ping -c 1 $HOST > /dev/null || { echo "@ Virtual machine host $HOST not visible !"; exit 1; }
}

download_pcap() {
    bin_dep 'wget'
    bin_dep 'tar'

    cd /tmp
    rm -rf libpcap-1.8.1
    if [ ! -f /tmp/libpcap-1.8.1.tar.gz ]; then
        echo "@ Downloading  https://www.tcpdump.org/release/libpcap-1.8.1.tar.gz ..."
        wget -q https://www.tcpdump.org/release/libpcap-1.8.1.tar.gz -O /tmp/libpcap-1.8.1.tar.gz
    fi
    tar xf libpcap-1.8.1.tar.gz
}

xcompile_pcap() {
    ARCH=$1
    HOST=$2
    COMPILER=$3

    bin_dep 'make'
    bin_dep 'yacc'
    bin_dep 'flex'
    bin_dep "$COMPILER"

    echo "@ Cross compiling libpcap for $ARCH with $COMPILER ..."
    cd /tmp/libpcap-1.8.1
    export CC=$COMPILER
    ./configure --host=$HOST --with-pcap=linux > /dev/null
    make CFLAGS='-w' -j4 > /dev/null
}

build_linux_amd64() {
    echo "@ Building linux/amd64 ..."
    go build $GO_BUILD_FLAGS -o bettercap ..
}

build_linux_arm7() {
    OLD=$(pwd)

    download_pcap
    xcompile_pcap 'arm' 'arm-linux-gnueabi' 'arm-linux-gnueabi-gcc'

    echo "@ Building linux/arm7 ..."
    cd "$OLD"
    env CC=arm-linux-gnueabi-gcc CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=7 CGO_LDFLAGS="$CROSS_LIB" go build $GO_BUILD_FLAGS -o bettercap ..
}

build_linux_mips() {
    OLD=$(pwd)

    download_pcap
    xcompile_pcap 'mips' 'mips-linux-gnu' 'mips-linux-gnu-gcc'

    echo "@ Building linux/mips ..."
    cd "$OLD"
    env CC=mips-linux-gnu-gcc CGO_ENABLED=1 GOOS=linux GOARCH=mips CGO_LDFLAGS="$CROSS_LIB" go build $GO_BUILD_FLAGS -o bettercap ..
}

build_linux_mipsle() {
    OLD=$(pwd)

    download_pcap
    xcompile_pcap 'mipsel' 'mipsel-linux-gnu' 'mipsel-linux-gnu-gcc'

    echo "@ Building linux/mipsle ..."
    cd "$OLD"
    env CC=mipsel-linux-gnu-gcc CGO_ENABLED=1 GOOS=linux GOARCH=mipsle CGO_LDFLAGS="$CROSS_LIB" go build $GO_BUILD_FLAGS -o bettercap ..
}

build_linux_mips64() {
    OLD=$(pwd)

    download_pcap
    xcompile_pcap 'mips64' 'mips64-linux-gnuabi64' 'mips64-linux-gnuabi64-gcc'

    echo "@ Building linux/mips64 ..."
    cd "$OLD"
    env CC=mips64-linux-gnuabi64-gcc CGO_ENABLED=1 GOOS=linux GOARCH=mips64 CGO_LDFLAGS="$CROSS_LIB" go build $GO_BUILD_FLAGS -o bettercap ..
}

build_linux_mips64le() {
    OLD=$(pwd)

    download_pcap
    xcompile_pcap 'mips64el' 'mips64el-linux-gnuabi64' 'mips64el-linux-gnuabi64-gcc'

    echo "@ Building linux/mips64le ..."
    cd "$OLD"
    env CC=mips64el-linux-gnuabi64-gcc CGO_ENABLED=1 GOOS=linux GOARCH=mips64le CGO_LDFLAGS="$CROSS_LIB" go build $GO_BUILD_FLAGS -o bettercap ..
}

build_macos_amd64() {
    host_dep 'osxvm'

    DIR=/Users/evilsocket/gocode/src/github.com/bettercap/bettercap

    echo "@ Updating repo on MacOS VM ..."
    ssh osxvm "cd $DIR && rm -rf '$OUTPUT' && git pull" > /dev/null

    echo "@ Building darwin/amd64 ..."
    ssh osxvm "export GOPATH=/Users/evilsocket/gocode && cd '$DIR' && PATH=$PATH:/usr/local/bin && go get ./... && go build $GO_BUILD_FLAGS -o bettercap ." > /dev/null

    scp -C osxvm:$DIR/bettercap . > /dev/null
}

build_windows_amd64() {
    host_dep 'winvm'

    DIR=c:/Users/evilsocket/gopath/src/github.com/bettercap/bettercap

    echo "@ Updating repo on Windows VM ..."
    ssh winvm "cd $DIR && git pull && go get ./..." > /dev/null

    echo "@ Building windows/amd64 ..."
    ssh winvm "cd $DIR && go build $GO_BUILD_FLAGS -o bettercap.exe ." > /dev/null

    scp -C winvm:$DIR/bettercap.exe . > /dev/null
}

build_android_arm() {
    host_dep 'shield'

    DIR=/data/data/com.termux/files/home/go/src/github.com/bettercap/bettercap

    echo "@ Updating repo on Android host ..."
    ssh -p 8022 root@shield "cd "$DIR" && rm -rf bettercap* && git pull && go get ./..."

    echo "@ Building android/arm ..."
    ssh -p 8022 root@shield "cd $DIR && go build $GO_BUILD_FLAGS -o bettercap ."

    echo "@ Downloading bettercap ..."
    scp -C -P 8022 root@shield:$DIR/bettercap . 
}

create_archive() {
    bin_dep 'zip'

    OUTPUT=$1

    echo "@ Creating archive $OUTPUT ..."
    zip -j "$OUTPUT" bettercap ../README.md ../LICENSE.md > /dev/null
    rm -rf bettercap bettercap.exe
}

rm -rf $BUILD_FOLDER
mkdir $BUILD_FOLDER
cd $BUILD_FOLDER

build_android_arm && create_archive bettercap_android_arm_$VERSION.zip
build_linux_amd64 && create_archive bettercap_linux_amd64_$VERSION.zip
build_linux_arm7 && create_archive bettercap_linux_arm7_$VERSION.zip
build_linux_mips && create_archive bettercap_linux_mips_$VERSION.zip
build_linux_mipsle && create_archive bettercap_linux_mipsle_$VERSION.zip
build_linux_mips64 && create_archive bettercap_linux_mips64_$VERSION.zip
build_linux_mips64le && create_archive bettercap_linux_mips64le_$VERSION.zip
build_macos_amd64 && create_archive bettercap_macos_amd64_$VERSION.zip
build_windows_amd64 && create_archive bettercap_windows_amd64_$VERSION.zip
sha256sum * > checksums.txt

echo
echo
du -sh *

cd --



