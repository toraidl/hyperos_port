<div align="center">


# HyperOS 移植项目
### 基于 https://github.com/ljc-fight/miui_port

简体中文&nbsp;&nbsp;|&nbsp;&nbsp;[English](/README_en-US.md) 

</div>

## 简介
- HyperOS 一键自动移植打包

## 测试机型及版本
- 测试机型小米10 底包 (V14.0.4.0.TJBCNXM)
- 测试版本 小米14Pro Android 14 OS1.0.09.0.UNBCNXM - OS1.0.20.0.UNBCNXM 官方OTA包

## 正常工作
- 人脸
- 挖孔
- 指纹
- 相机（基础功能）
- 自动亮度
- 通话息屏
- 应用双开
- 护眼模式
- 带壳截屏


## BUG
- NFC（mi10可刷卡）

- 等你发现

## 说明
- 以上均基于小米10正式版(V14.0.4.0.TJBCNXM)测试

## 如何使用
- 在WSL、ubuntu、deepin等Linux下
```shell
    sudo apt update
    sudo apt upgrade
    sudo apt install git -y
    # 克隆项目
    git clone https://github.com/toraidl/hyperos_port.git
    cd hyperos_port
    # 安装依赖
    sudo ./setup.sh
    # 开始移植
    sudo ./port.sh <底包路径> <移植包路径>
```
- 在macOS下
```shell
    # 安装brew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # 克隆项目
    git clone https://github.com/toraidl/hyperos_port.git
    cd hyperos_port
    # 安装依赖
    sudo ./setup.sh
    # 开始移植
    sudo ./port.sh <底包路径> <移植包路径>
```
- 在Termux上(未测试)
```shell
    pkg update
    pkg upgrade
    pkg install git tsu -y
    # 克隆项目
    git clone https://github.com/toraidl/hyperos_port.git
    cd hyperos_port/
    # 安装依赖
    ./setup.sh
    # 进入root模式
    tsu
    ./port.sh <底包路径> <移植包路径>
```
- 上述代码中，底包路径和移植包路径可以替换为链接