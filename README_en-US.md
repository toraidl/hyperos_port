<div align="center">


# HyperOS Porting Project
### Based on https://github.com/ljc-fight/miui_port

[简体中文](/README.md)&nbsp;&nbsp;|&nbsp;&nbsp;English

</div>

## Intro
- HyperOS Porting Project for Android 13 devices "Onekey" script

## Tested devices and portroms
- Tested Devices: Xiaomi 10/Pro/Ultra(umi/cmi/cas) (with latest stock MIUI14 ROM)
- Tested Ports: Xiaomi Mi 13/13Pro/14/14Pro K70Pro Stable and Dev stock flashable zip

## Working
- Face unlock
- Fringerprint
- Camera(from leaked mi10s A13 based hyperos)
- Automatic Brightness
- NFC
- etc


## BUG

- When unlocking device, the screen may flicker , Enabling "Disable HW overlays" in Developer options may help.

## Description
- All the above testing is based on Xiaomi 10/10Pro/10 Ultra official MIUI 14 version. for V-AB devices, tester needed. 

## How to use
- On WSL、ubuntu、deepin and other Linux
```shell
    sudo apt update
    sudo apt upgrade
    sudo apt install git -y
    # Clone project
    git clone https://github.com/toraidl/hyperos_port.git
    cd hyperos_port
    # Install dependencies
    sudo ./setup.sh
    # Start porting
    sudo ./port.sh <baserom> <portrom>
```
- on macOS (AMD64)
```shell
    # Install brew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Clone project
    git clone https://github.com/toraidl/hyperos_port.git
    cd hyperos_port
    # Install dependencies
    sudo ./setup.sh
     # Start porting
    sudo ./port.sh <baserom> <portrom>
```
- On Termux Android (not tested)
```shell
    pkg update
    pkg upgrade
    pkg install git tsu -y
    # Clone project
    git clone https://github.com/toraidl/hyperos_port.git
    cd hyperos_port/
    # Install depenencies
    ./setup.sh
    # Enter root mode 
    tsu
    ./port.sh <baserom> <portrom>
```
- baserom and portrom can be a direct download link. you can get the ota download link  from third-party websites.

## Credits
> In this project, some or all of the content is derived from the following open-source projects. Special thanks to the developers of these projects.

- [「BypassSignCheck」by Weverses](https://github.com/Weverses/BypassSignCheck)
- [「contextpatch」 by ColdWindScholar](https://github.com/ColdWindScholar/TIK)
- [「fspatch」by affggh](https://github.com/affggh/fspatch)
- [「gettype」by affggh](https://github.com/affggh/gettype)
- [「lpunpack」by unix3dgforce](https://github.com/unix3dgforce/lpunpack)
- [「miui_port」by ljc-fight](https://github.com/ljc-fight/miui_port)
- etc