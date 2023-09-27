# MIUI V-A/B 机型移植项目

## 简介
- MIUI14安卓13移植一键自动完成

## 测试机型及版本
- 测试机型小米10S 底包 (V14.0.6.0.TGACNXM)
- 测试版本 小米13 Android 13 V14.0.23.9.18.DEV
- 测试版本 小米13Pro Android 13 V14.0.23.9.18.DEV
- 测试版本 小米13Ultra Android 13 V14.0.23.9.18.DEV

## 正常工作
- NFC
- 人脸
- 挖孔
- 相机
- 指纹
- 自动亮度
- 通话息屏
- 应用双开
- 护眼模式
- 带壳截屏

## BUG
- DPI偏小
- 等你发现

## 说明
- 以上均基于小米10S正式版(V14.0.6.0.TGACNXM)测试
- 联发科未测试

## 如何使用
- 在WSL、ubuntu、deepin等Linux下
```shell
    sudo apt update
    sudo apt upgrade
    sudo apt install git -y
    # 克隆项目
    git clone https://github.com/ljc-fight/miui_port.git
    cd miui_port
    # 安装依赖
    sudo bash setup.sh
    # 开始移植
    sudo bash miui_port.sh <底包路径> <移植包路径>
```

- 在Termux上
```shell
    pkg update
    pkg upgrade
    pkg install git tsu -y
    # 克隆项目
    git clone https://github.com/ljc-fight/miui_port.git
    cd miui_port/
    # 安装依赖
    bash setup.sh
    # 进入root模式
    tsu
    bash miui_port.sh <底包路径> <移植包路径>
```
- 上述代码中，底包路径和移植包路径可以替换为链接