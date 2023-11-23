#!/bin/bash
# port requirements

if [ "$(id -u)" != "0" ] && [ "$(uname -m)" == "x86_64" ];then
    echo "请以 root 用户运行"
    exit
fi

if [ "$(uname -m)" == "x86_64" ] && [  "$(uname)" == "Linux" ];then
    echo "Device arch: Linux x86_64"
    apt update -y
    apt upgrade -y
    apt install -y aria2 python3 busybox zip unzip p7zip-full openjdk-8-jre zipalign
    if [ $? -ne 0 ];then
        echo "安装可能出错，请手动执行：apt install -y python3 busybox zip unzip p7zip-full"
    fi
fi

if [ "$(uname -m)" == "aarch64" ];then
    echo "Device arch: aarch64"
    apt update -y
    apt upgrade -y
    apt install -y python busybox zip unzip p7zip openjdk-17 zipalign
fi

if [ "$(uname -m)" == "darwin" ] && [ "$(uname -m)" == "x86_64" ];then
    echo "Devcie arch: MacOS X86_X64"
    brew install aria2 openjdk zstd coreutils
fi