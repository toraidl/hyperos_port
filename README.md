<div align="center">

# HyperOS 移植项目
### 基于 https://github.com/ljc-fight/miui_port

简体中文&nbsp;&nbsp;|&nbsp;&nbsp;[English](/README_en-US.md) 

</div>

## 简介
- HyperOS 一键自动移植打包


## 测试机型及版本
- 测试机型小米10/Pro/Ultra MIUI 14最新版
- 测试版本 小米12、小米13/Pro/Ultra、小米14/Pro HyperOS1.0 正式版和开发版 官方OTA包 & xiaomi.eu官改包
- 测试版本 小米平板5 Pro 12.4（DAGU）


## 正常工作
- 人脸
- 挖孔
- 指纹
- 相机
- NFC
- 自动亮度
- 通话息屏
- 应用双开
- 护眼模式
- 带壳截屏


## BUG

- 等你发现

## 说明
- 以上CN ROM均基于小米10正式版(V14.0.4.0.TJBCNXM)底包
- 欧版基于最新xiaomi.eu官方的最新MIUI14底包

## 平板系统
移植平板HyperOS到手机，需要从其他正常手机HyperOS机型复制下面的软件
Contacts MIUIAod MiuiHome MIUISecurityCenter  Mms  MIUIContentExtension  MIUIPackageInstaller


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

## 感谢
> 本项目使用了以下开源项目的部分或全部内容，感谢这些项目的开发者（排名顺序不分先后）。

- [「BypassSignCheck」by Weverses](https://github.com/Weverses/BypassSignCheck)
- [「contextpatch」 by ColdWindScholar](https://github.com/ColdWindScholar/TIK)
- [「fspatch」by affggh](https://github.com/affggh/fspatch)
- [「gettype」by affggh](https://github.com/affggh/gettype)
- [「lpunpack」by unix3dgforce](https://github.com/unix3dgforce/lpunpack)
- [「miui_port」by ljc-fight](https://github.com/ljc-fight/miui_port)
- etc
