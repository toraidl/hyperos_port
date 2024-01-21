#!/bin/bash
# port requirements

if [ "$(id -u)" != "0" ] && [ "$(uname -m)" == "x86_64" ]  && [  "$(uname)" == "Linux" ];then
    echo "请以 root 用户运行"
    echo "please run with sudo"
    exit
fi

if [ "$(uname -m)" == "x86_64" ] && [  "$(uname)" == "Linux" ];then
    echo "Device arch: Linux x86_64"
    apt update -y
    apt upgrade -y
    apt install -y aria2 python3 busybox zip unzip p7zip-full openjdk-8-jre zipalign zstd bc android-sdk-libsparse-utils xmlstarlet
    if [ $? -ne 0 ];then
        echo "安装可能出错，请手动执行：apt install -y aria2 python3 busybox zip unzip p7zip-full openjdk-8-jre zipalign zstd bc xmlstarlet"
    fi
fi

if [ "$(uname -m)" == "aarch64" ];then
    echo "Device arch: aarch64"
    apt update -y
    apt upgrade -y
    apt install -y python busybox zip unzip p7zip openjdk-17 zipalign zstd xmlstarlet
fi

if [ "$(uname)" == "Darwin" ] && [ "$(uname -m)" == "x86_64" ];then
    echo "Devcie arch: MacOS X86_X64"
    pip3 install buysbox
    brew install aria2 openjdk zstd coreutils gdu gnu-sed gnu-getopt grep xmlstarlet
fi