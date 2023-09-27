@echo off
cd %~dp0

if exist images\super.img.zst META-INF\platform-tools\zstd --rm -d images\super.img.zst -o images\super.img

rem

if exist images\cust.img META-INF\platform-tools\fastboot flash super images\cust.img
if exist images\super.img META-INF\platform-tools\fastboot flash super images\super.img
META-INF\platform-tools\fastboot set_active a
META-INF\platform-tools\fastboot reboot
pause