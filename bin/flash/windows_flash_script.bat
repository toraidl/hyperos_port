@echo off
cls
reg query "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Nls\Language" /v InstallLanguage|find "0804">nul&& set LANG=Chinese
if "%LANG%"=="Chinese" (
    TITLE windows 刷机脚本 [请勿选中窗口，卡住按右键或回车或放大缩小窗口恢复]
) else (
    TITLE Windows Flash Script
)
color 3f
echo.
if exist "super.zst" (
    if "%LANG%"=="Chinese" (
        echo. 正在解压super镜像,耐心等待
    ) else (
        echo. Extracting the super image, wait patiently
    )
    bin\windows\zstd.exe --rm -d super.zst -o super.img
    if not "%errorlevel%" == "0" (
        if "%LANG%"=="Chinese" (
            echo. 转换失败,按任意键退出
        ) else (
            echo. Conversion failed. Press any key to exit
        )
        pause >nul 2>nul
        exit
    )
)

if "%LANG%"=="Chinese" (
    echo.
    echo. 1. 保留数据刷入
    echo.
    echo. 2. 双清刷入
    echo.
    set /p input=请选择-默认选择1,回车执行:
) else (
    echo.
    echo. 1. Preserve user data during flashing
    echo.
    echo. 2. Wiping data without wiping /data/media
    echo.
    set /p input=Please select - 1 is selected by default, and enter to execute:
)

if exist boot_tv.img (
    if "%LANG%"=="Chinese" (
	    echo. 刷入第三方boot_tv.img
        
    ) else (
        echo. Flashing custom boot.img
    ) 
    bin\windows\fastboot.exe flash boot %~dp0boot_tv.img

) else (
    bin\windows\fastboot.exe flash boot %~dp0boot_official.img
)

REM firmware

bin\windows\fastboot.exe erase super
bin\windows\fastboot.exe reboot bootloader
ping 127.0.0.1 -n 5 >nul 2>nul
bin\windows\fastboot.exe flash super %~dp0super.img
if "%input%" == "2" (
	if "%LANG%"=="Chinese" (
	    echo. 正在双清系统,耐心等待
    ) else (
        echo. Wiping data without wiping /data/media/, please wait patiently
    ) 
	bin\windows\fastboot.exe erase userdata
	bin\windows\fastboot.exe erase metadata
)

REM SET_ACTION_SLOT_A_BEGIN
if "%LANG%"=="Chinese" (
	echo. 设置活动分区为 'a'。可能需要一些时间。请勿手动重新启动或拔掉数据线，否则可能导致设备变砖。
) else (
    echo. Starting the process to set the active slot to 'a.' This may take some time. Please refrain from manually restarting or unplugging the data cable, as doing so could result in the device becoming unresponsive.
)
bin\windows\fastboot.exe set_active a

REM SET_ACTION_SLOT_A_END

bin\windows\fastboot.exe reboot

if "%LANG%"=="Chinese" (
    echo. 刷机完成,若手机长时间未重启请手动重启,按任意键退出
) else (
    echo. Flash completed. If the phone does not restart for an extended period, please manually restart. Press any key to exit.
)
pause
exit
