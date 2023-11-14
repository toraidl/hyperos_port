#!/bin/bash

# hyperOS_port project

# For A-only and V/A-B (not tested) Devices

# Based on Android 13

# Test Base ROM: A-only Mi 10 (V14.0.4)

# Test Port ROM: Mi14 Pro OS1.0.9-1.0.21


BUILDUSER="Bruce Teng"
BUILDHOST=$(hostname)

# 底包和移植包为外部参数传入
BASEROM="$1"
PORTROM="$2"

WORK_DIR=$(pwd)
TOOLS_DIR=${WORK_DIR}/bin/$(uname)/$(uname -m)
export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

shopt -s expand_aliases
if [[ $(uname) == "Darwin" ]]; then
    echo "macOS detected,setting alias"
    alias sed=gsed
    alias tr=gtr
    alias grep=ggrep
    alias du=gdu
    #alias find=gfind
fi
# 定义颜色输出函数
Error() {
    if [[ $(uname) == "Darwin" ]]; then
       echo -e "$(date '+%m%d-%T')" "$(tput setaf 1)""$@""$(tput sgr0)"
    else
        echo -e \[$(date +%m%d-%T)\] "\e[1;31m"$@"\e[0m"
    fi
}

Yellow() {
    if [[ $(uname) == "Darwin" ]]; then
        echo -e "$(date '+%m%d-%T')" "$(tput setaf 3)""$@""$(tput sgr0)"
    else
        echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"
    fi
}

Blue() {
    if [[ $(uname) == "Darwin" ]]; then
        echo -e "$(date '+%m%d-%T')" "$(tput setaf 4)""$@""$(tput sgr0)"
    else
        echo -e \[$(date +%m%d-%T)\] "\e[1;34m"$@"\e[0m"
    fi
}

Green() {
    if [[ $(uname) == "Darwin" ]]; then
        echo -e "$(date '+%m%d-%T')" "$(tput setaf 2)""$@""$(tput sgr0)"
    else
	    echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"
    fi
}

# 向 apk 或 jar 文件中替换 smali 代码，不支持资源补丁
# $1: 目标 apk/jar 文件
# $2: 目标 smali 文件
# $3: 被替换值
# $4: 替换值
patch_smali() {
    targetfilefullpath=$(find build/PORTROM/images -type f -name $1)
    targetfilename=$(basename $targetfilefullpath)
    if [ -f $targetfilefullpath ];then
        Yellow "正在修改 $targetfilename"
        foldername=${targetfilename%.*}
        rm -rf tmp/$foldername/
        mkdir -p tmp/$foldername/
        cp -rf $targetfilefullpath tmp/$foldername/
        7z x -y tmp/$foldername/$targetfilename *.dex -otmp/$foldername >/dev/null
        for dexfile in $(ls tmp/$foldername/*.dex);do
            Yellow I: Baksmaling $dexfile
            smalifname=${dexfile%.*}
            smalifname=$(echo $smalifname | cut -d "/" -f 3)
            java -jar bin/apktool/baksmali.jar d --api ${port_android_sdk} ${dexfile} -o tmp/$foldername/$smalifname
        done

        targetsmali=$(find tmp/$foldername -type f -name $2)
        if [ -f $targetsmali ];then
            smalidir=$(echo $targetsmali |cut -d "/" -f 3)
            Yellow I: 找到目标 $(basename ${targetsmali}) 位于 ${smalidir}.dex 文件
            
            Yellow I: 开始patch目标 ${smalidir}
            search_pattern=$3
            repalcement_pattern=$4
            sed -i "s/$search_pattern/$repalcement_pattern/g" $targetsmali
            #rm -rf ${targetfilefullpath}
            Yellow I: Smaling smali_${smalidir} 文件夹回 ${smalidir}.dex
            java -jar bin/apktool/smali.jar a --api ${port_android_sdk} tmp/$foldername/${smalidir} -o tmp/$foldername/${smalidir}.dex
            cd tmp/$foldername/ || exit
            #macOS上用7z添加文件到apk会提示错误,jar正常
            #fixme
            if [ $(uname) = "Darwin" ];then
                zip -our $targetfilename ${smalidir}.dex
            else
                7z a -y -mx0 $targetfilename ${smalidir}.dex
            fi
            cd ../../
            cp -rfv tmp/$foldername/$targetfilename ${targetfilefullpath}
            fi
    fi

}

#重新打包apk后会崩，暂不知原因，弃用
#fixme
patch_apk() {
    if [[ $5 == "1" ]];then
        nores="--no-res"
    else
        nores=""
    fi
    apkfile=$(find build/PORTROM/images -type f -name "$1")
    if [ -f $apkfile ]; then
        mkdir -p tmp/
        apkname=$(basename $apkfile | cut -d "." -f 1)
        bin/apktool/apktool d $nores $apkfile -o tmp/$apkname -f
        targetSmali=$(find tmp/$apkname -type f -name "$2")
        Yellow "找到目标$targetSmali patching..."
        if sed -i "s/$3/$4/g" $targetSmali; then 
            Yellow "patch $3成功，开始重新打包并替换$apkfile"
             bin/apktool/apktool b tmp/$apkname -o $apkname.apk -f
            cp -Rf $apkname.apk $apkfile
        else
            Error "patch失败，检查是否方法已改变"
        fi 
    fi
}

# 移植的分区，可在 bin/port_config 中更改
PORT_PARTITION=$(grep "partition_to_port" bin/port_config |cut -d '=' -f 2)
#SUPERLIST=$(grep "super_list" bin/port_config |cut -d '=' -f 2)
REPACKEXT4=$(grep "repack_with_ext4" bin/port_config |cut -d '=' -f 2)
# 检查为本地包还是链接

if [ ! -f "${BASEROM}" ] && [ "$(echo $BASEROM |grep http)" != "" ];then
    Blue "底包为一个链接，正在尝试下载"
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${BASEROM}
    BASEROM=$(basename ${BASEROM})
    if [ ! -f "${BASEROM}" ];then
        Error "下载错误"
    fi
elif [ -f "${BASEROM}" ];then
    Green "底包: ${BASEROM}"
else
    Error "底包参数错误"
    exit
fi

if [ ! -f "${PORTROM}" ] && [ "$(echo ${PORTROM} |grep http)" != "" ];then
    Blue "移植包为一个链接，正在尝试下载"
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${PORTROM}
    PORTROM=$(basename ${PORTROM})
    if [ ! -f "${PORTROM}" ];then
        Error "下载错误"
    fi
elif [ -f "${PORTROM}" ];then
    Green "移植包: ${PORTROM}"
else
    Error "移植包参数错误"
    exit
fi

if [ "$(echo $BASEROM |grep miui_)" != "" ];then
    deviceCode=$(basename $BASEROM |cut -d '_' -f 2)
else
    deviceCode="YourDevice"
fi


Blue "正在检测ROM底包"
if unzip -l ${BASEROM} | grep -q "payload.bin"; then
    baseROMType="payload"
    SUPERLIST="vendor mi_ext odm odm_dlkm system system_dlkm vendor_dlkm product product_dlkm system_ext"
elif unzip -l ${BASEROM} | grep -q "br$";then
    baseROMType="br"
    SUPERLIST="vendor mi_ext odm system product system_ext"
    
else
    Error "底包中未发现payload.bin以及br文件，请使用MIUI官方包后重试"
    exit
fi

Blue "开始检测ROM移植包"
unzip -l ${PORTROM} |grep "payload.bin" 1>/dev/null 2>&1 ||{ Error "目标移植包没有payload.bin，请用MIUI官方包作为移植包"; exit 1; }

Green "ROM初步检测通过"

Blue "正在清理文件"
for i in ${PORT_PARTITION};do
    [ -d ./${i} ] && rm -rf ./${i}
done
sudo rm -rf app
sudo rm -rf tmp
sudo rm -rf config
sudo rm -rf build/BASEROM/
sudo rm -rf build/PORTROM/
find . -type d -name 'hyperos_*' |xargs rm -rf

Green "文件清理完毕"


mkdir -p build/BASEROM/images/
mkdir -p build/BASEROM/config/
mkdir -p build/PORTROM/images/
mkdir -p build/PORTROM/config/
# 提取分区
if [ ${baseROMType} = 'payload' ];then
    Blue "正在提取底包 [payload.bin]"
    unzip ${BASEROM} payload.bin -d build/BASEROM ||Error "解压底包 [payload.bin] 时出错"
    Green "底包 [payload.bin] 提取完毕"
else
    Blue "正在提取底包 [new.dat.br]"
    unzip ${BASEROM} -d build/BASEROM || Error "解也底包 [new.dat.br]时出错"
    Green "底包 [new.dat.br] 提取完毕"
fi

Blue "正在提取移植包 [payload.bin]"
unzip ${PORTROM} payload.bin -d build/PORTROM ||Error "解压移植包 [payload.bin] 时出错"
Green "移植包 [payload.bin] 提取完毕"

if [ ${baseROMType} = 'payload' ];then

    Blue "开始分解底包 [payload.bin]"
    payload-dumper-go -o build/BASEROM/images/ build/BASEROM/payload.bin >/dev/null 2>&1 ||Error "分解底包 [payload.bin] 时出错"
else
    Blue "开始分解底包 [new.dat.br]"
        for i in ${SUPERLIST}; do
            ${TOOLS_DIR}/brotli -d build/BASEROM/$i.new.dat.br >/dev/null 2>&1
            sudo python3 ${TOOLS_DIR}/sdat2img.py build/BASEROM/$i.transfer.list build/BASEROM/$i.new.dat build/BASEROM/images/$i.img >/dev/null 2>&1
            rm -rf $i.new.data.* $i.transfer.list $i.patch.*
        done
fi

for part in system system_dlkm system_ext product product_dlkm mi_ext ;do
    if [[ -f build/BASEROM/images/${part}.img ]];then 
        if [[ $($TOOLS_DIR/gettype -i build/BASEROM/images/${part}.img) == "ext" ]];then
            packType=EXT
            Blue "正在分解底包 ${part}.img [ext]"
            sudo python3 bin/imgextractor/imgextractor.py build/BASEROM/images/${part}.img >/dev/null 2>&1
            Blue "分解底包 [${part}.img] 完成，移到build/BASEROM/images文件夹"
            mv ${part} build/BASEROM/images/
            
        elif [[ $($TOOLS_DIR/gettype -i build/BASEROM/images/${part}.img) == "erofs" ]]; then
            packType=EROFS
            Blue "正在分解底包 ${part}.img [erofs]"
            extract.erofs -x -i build/BASEROM/images/${part}.img
                Blue "分解底包 [${part}.img][ext] 完成，移到build/BASEROM/images文件夹"
            mv ${part} build/BASEROM/images/
            
        fi
        mv config/*${part}* build/BASEROM/config/
    fi
    #mv config/${part}_size.txt build/BASEROM/config/
    #mv config/${part}_fs_config build/BASEROM/config/
    #mv config/${part}_file_contexts build/BASEROM/config/
    
done

for image in vendor odm vendor_dlkm odm_dlkm;do
    if [ -f build/BASEROM/images/${image}.img ];then
        cp -rf build/BASEROM/images/${image}.img build/PORTROM/images/${image}.img
    fi
done

# 分解镜像
Green 开始提取逻辑分区镜像

for part in ${SUPERLIST};do
    if [[ $part =~ ^(vendor|odm|vendor_dlkm|odm_dlkm)$ ]] && [[ -f "build/PORTROM/images/$part.img" ]]; then
        Blue "从底包中提取 [${part}]分区 ..."
    else
        Blue "paylaod.bin 提取 [${part}] 分区..."
        payload-dumper-go -p ${part} -o build/PORTROM/images/ build/PORTROM/payload.bin >/dev/null 2>&1 ||Error "提取移植包 [${part}] 分区时出错"
    fi
    if [ -f "${WORK_DIR}/build/PORTROM/images/${part}.img" ];then
        Blue 开始提取 ${part}.img
        
        if [[ $($TOOLS_DIR/gettype -i build/PORTROM/images/${part}.img) == "ext" ]];then
            packType=EXT
            python3 bin/imgextractor/imgextractor.py build/PORTROM/images/${part}.img
            mv ${part} build/PORTROM/images/
            mkdir -p build/PORTROM/images/${part}/lost+found
            mv config/*${part}* build/PORTROM/config/
            
            rm -rf build/PORTROM/images/${part}.img

            Green "提取 [${part}] [ext]镜像完毕"
        elif [[ $(gettype -i build/PORTROM/images/${part}.img) == "erofs" ]];then
            packType=EROFS
            Green "移植包为 [erofs] 文件系统"
            [ "${REPACKEXT4}" = "true" ] && packType=EXT
            extract.erofs -x -i build/PORTROM/images/${part}.img
            mv ${part} build/PORTROM/images/
            mkdir -p build/PORTROM/images/${part}/lost+found
            mv config/*${part}* build/PORTROM/config/
            rm -rf build/PORTROM/images/${part}.img

            Green "提取移植包[${part}] [erofs]镜像完毕"
        fi
        
    fi
done
Yellow "打包类型设置为$packType"
rm -rf config


# 获取ROM参数

Blue "正在获取ROM参数"
# 安卓版本
base_android_version=$(< build/PORTROM/images/vendor/build.prop grep "ro.vendor.build.version.release" |awk 'NR==1' |cut -d '=' -f 2)
port_android_version=$(< build/PORTROM/images/system/system/build.prop grep "ro.system.build.version.release" |awk 'NR==1' |cut -d '=' -f 2)
Green "安卓版本: 底包为[Android ${base_android_version}], 移植包为 [Android ${port_android_version}]"

# SDK版本
base_android_sdk=$(< build/PORTROM/images/vendor/build.prop grep "ro.vendor.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
port_android_sdk=$(< build/PORTROM/images/system/system/build.prop grep "ro.system.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
Green "SDK 版本: 底包为 [SDK ${base_android_sdk}], 移植包为 [SDK ${port_android_sdk}]"

# ROM版本
base_rom_version=$(< build/PORTROM/images/vendor/build.prop grep "ro.vendor.build.version.incremental" |awk 'NR==1' |cut -d '=' -f 2)

#HyperOS版本号获取
port_mios_version_incremental=$(< build/PORTROM/images/mi_ext/etc/build.prop grep "ro.mi.os.version.incremental" | awk 'NR==1' | cut -d '=' -f 2)
#替换机型代号,比如小米10：UNBCNXM -> UJBCNXM

port_device_code=$(echo $port_mios_version_incremental | cut -d "." -f 5)

if [[ $port_mios_version_incremental == *DEV* ]];then
    Yellow "Dev deteced,skip replacing codename"
    port_rom_version=$(echo $port_mios_version_incremental)
else
    base_device_code=U$(echo $base_rom_version | cut -d "." -f 5 | cut -c 2-)
    port_rom_version=$(echo $port_mios_version_incremental | sed "s/$port_device_code/$base_device_code/")
fi
Green "ROM 版本: 底包为 [${base_rom_version}], 移植包为 [${port_rom_version}]"

# MIUI版本
base_miui_version=$(< build/BASEROM/images/product/etc/build.prop grep "ro.miui.ui.version.code" |awk 'NR==1' |cut -d '=' -f 2)
port_miui_version=$(< build/PORTROM/images/product/etc/build.prop grep "ro.miui.ui.version.code" |awk 'NR==1' |cut -d '=' -f 2)

Green "MIUI版本: 底包为 [${base_miui_version}], 移植包为 [${port_miui_version}]"


# 代号
base_rom_code=$(< build/PORTROM/images/vendor/build.prop grep "ro.product.vendor.device" |awk 'NR==1' |cut -d '=' -f 2)
port_rom_code=$(< build/PORTROM/images/product/etc/build.prop grep "ro.product.product.name" |awk 'NR==1' |cut -d '=' -f 2)
Green "机型代号: 底包为 [${base_rom_code}], 移植包为 [${port_rom_code}]"


#原机display配置卡一屏问题
baseAospFrameworkResOverlay=$(find build/BASEROM/images/product -type f -name "AospFrameworkResOverlay.apk")
portAospFrameworkResOverlay=$(find build/PORTROM/images/product -type f -name "AospFrameworkResOverlay.apk")
if [ -f "${baseAospFrameworkResOverlay}" ] && [ -f "${portAospFrameworkResOverlay}" ];then
    Blue "正在替换 [AospFrameworkResOverlay.apk]"
    cp -rf ${baseAospFrameworkResOverlay} ${portAospFrameworkResOverlay}
fi


#baseMiuiFrameworkResOverlay=$(find build/BASEROM/images/product -type f -name "MiuiFrameworkResOverlay.apk")
#portMiuiFrameworkResOverlay=$(find build/PORTROM/images/product -type f -name "MiuiFrameworkResOverlay.apk")
#if [ -f ${baseMiuiFrameworkResOverlay} ] && [ -f ${portMiuiFrameworkResOverlay} ];then
#    Blue "正在替换 [MiuiFrameworkResOverlay.apk]"
#    cp -rf ${baseMiuiFrameworkResOverlay} ${portMiuiFrameworkResOverlay}
#fi

#baseAospWifiResOverlay=$(find build/BASEROM/images/product -type f -name "AospWifiResOverlay.apk")
##portAospWifiResOverlay=$(find build/PORTROM/images/product -type f -name "AospWifiResOverlay.apk")
#if [ -f ${baseAospWifiResOverlay} ] && [ -f ${portAospWifiResOverlay} ];then
#    Blue "正在替换 [AospWifiResOverlay.apk]"
#    cp -rf ${baseAospWifiResOverlay} ${portAospWifiResOverlay}
#fi

baseDevicesAndroidOverlay=$(find build/BASEROM/images/product -type f -name "DevicesAndroidOverlay.apk")
portDevicesAndroidOverlay=$(find build/PORTROM/images/product -type f -name "DevicesAndroidOverlay.apk")
if [ -f "${baseDevicesAndroidOverlay}" ] && [ -f "${portDevicesAndroidOverlay}" ];then
    Blue "正在替换 [DevicesAndroidOverlay.apk]"
    cp -rf ${baseDevicesAndroidOverlay} ${portDevicesAndroidOverlay}
fi

baseDevicesOverlay=$(find build/BASEROM/images/product -type f -name "DevicesOverlay.apk")
portDevicesOverlay=$(find build/PORTROM/images/product -type f -name "DevicesOverlay.apk")
if [ -f "${baseDevicesOverlay}" ] && [ -f "${portDevicesOverlay}" ];then
    Blue "正在替换 [DevicesOverlay.apk]"
    cp -rf ${baseDevicesOverlay} ${portDevicesOverlay}
fi

baseMiuiBiometricResOverlay=$(find build/BASEROM/images/product -type f -name "MiuiBiometricResOverlay.apk")
portMiuiBiometricResOverlay=$(find build/PORTROM/images/product -type f -name "MiuiBiometricResOverlay.apk")
if [ -f "${baseMiuiBiometricResOverlay}" ] && [ -f "${portMiuiBiometricResOverlay}" ];then
    Blue "正在替换 [MiuiBiometricResOverlay.apk]"
    cp -rf ${baseMiuiBiometricResOverlay} ${portMiuiBiometricResOverlay}
fi

# radio lib
# Blue "信号相关"
# for radiolib in $(find build/BASEROM/images/system/system/lib/ -maxdepth 1 -type f -name "*radio*");do
#     cp -rf $radiolib build/PORTROM/images/system/system/lib/
# done

# for radiolib in $(find build/BASEROM/images/system/system/lib64/ -maxdepth 1 -type f -name "*radio*");do
#     cp -rf $radiolib build/PORTROM/images/system/system/lib64/
# done


# audio lib
# Blue "音频相关"
# for audiolib in $(find build/BASEROM/images/system/system/lib/ -maxdepth 1 -type f -name "*audio*");do
#     cp -rf $audiolib build/PORTROM/images/system/system/lib/
# done

# for audiolib in $(find build/BASEROM/images/system/system/lib64/ -maxdepth 1 -type f -name "*audio*");do
#     cp -rf $audiolib build/PORTROM/images/system/system/lib64/
# done

# # bt lib
# Blue "蓝牙相关"
# for btlib in $(find build/BASEROM/images/system/system/lib/ -maxdepth 1 -type f -name "*bluetooth*");do
#     cp -rf $btlib build/PORTROM/images/system/system/lib/
# done

# for btlib in $(find build/BASEROM/images/system/system/lib64/ -maxdepth 1 -type f -name "*bluetooth*");do
#     cp -rf $btlib build/PORTROM/images/system/system/lib64/
# done


# displayconfig id
Blue "正在替换 displayconfig"
rm -rf build/PORTROM/images/product/etc/displayconfig/display_id*.xml
cp -rf build/BASEROM/images/product/etc/displayconfig/* build/PORTROM/images/product/etc/displayconfig/


# device_features
Blue "正在替换 device_features"   
rm -rf build/PORTROM/images/product/etc/device_features/*
cp -rf build/BASEROM/images/product/etc/device_features/* build/PORTROM/images/product/etc/device_features/


# MiSound
#baseMiSound=$(find build/BASEROM/images/product -type d -name "MiSound")
#portMiSound=$(find build/BASEROM/images/product -type d -name "MiSound")
#if [ -d ${baseMiSound} ] && [ -d ${portMiSound} ];then
#    Blue "正在替换 MiSound"
 #   rm -rf ./${portMiSound}/*
 #   cp -rf ./${baseMiSound}/* ${portMiSound}/
#fi

# MusicFX
#baseMusicFX=$(find build/BASEROM/images/product build/BASEROM/images/system -type d -name "MusicFX")
#portMusicFX=$(find build/BASEROM/images/product build/BASEROM/images/system -type d -name "MusicFX")
#if [ -d ${baseMusicFX} ] && [ -d ${portMusicFX} ];then
#    Blue "正在替换 MusicFX"
##    rm -rf ./${portMusicFX}/*
 #   cp -rf ./${baseMusicFX}/* ${portMusicFX}/
#fi

# 人脸
baseMiuiBiometric=$(find build/BASEROM/images/product/app -type d -name "MiuiBiometric*")
portMiuiBiometric=$(find build/PORTROM/images/product/app -type d -name "MiuiBiometric*")
if [ -d "${baseMiuiBiometric}" ] && [ -d "${portMiuiBiometric}" ];then
    Blue "替换MiuiBiometric.."
    rm -rf ./${portMiuiBiometric}/*
    cp -rf ./${baseMiuiBiometric}/* ${portMiuiBiometric}/
else
    if [ -d "${baseMiuiBiometric}" ] && [ ! -d "${portMiuiBiometric}" ];then
        Blue "未找到MiuiBiometric,从原ROM中复制..."
        cp -rf ${baseMiuiBiometric} build/PORTROM/images/product/app/
    fi
fi


# 修复AOD问题
targetDevicesAndroidOverlay=$(find build/PORTROM/images/product -type f -name "DevicesAndroidOverlay.apk")
if [[ -f $targetDevicesAndroidOverlay ]]; then
    mkdir tmp/  
    filename=$(basename $targetDevicesAndroidOverlay)
    Yellow "解包 $filename ...修复aod问题"
    targetDir=$(echo "$filename" | sed 's/\..*$//')
    bin/apktool/apktool d $targetDevicesAndroidOverlay -o tmp/$targetDir -f 
    search_pattern="com\.miui\.aod\/com\.miui\.aod\.doze\.DozeService"
    replacement_pattern="com\.android\.systemui\/com\.android\.systemui\.doze\.DozeService"
    for xml in $(find tmp/$targetDir -type f -name "*.xml");do
        sed -i "s/$search_pattern/$replacement_pattern/g" $xml
    done
    bin/apktool/apktool b tmp/$targetDir -o tmp/$filename
    Yellow "修改完成，替换$targetDevicesAndroidOverlay"
    cp -rf tmp/$filename $targetDevicesAndroidOverlay
    rm -rf tmp
fi



# 修复NFC
Blue "正在修复/替换 NFC"
Yellow "TODO"
#mi_ext文件复制到product
#cp -rf build/PORTROM/images/mi_ext/product/overlay/* build/PORTROM/images/product/overlay
#cp -rf build/PORTROM/images/mi_ext/product/framework/* build/PORTROM/images/product/framework
#cp -rf build/PORTROM/images/mi_ext/product/etc/permissions/platform-miui-uninstall.xml build/PORTROM/images/product/etc/permissions
#cat build/PORTROM/images/mi_ext/etc/build.prop >> build/PORTROM/images/product/etc/build.prop
#pangu移动到system
#cp -rf build/PORTROM/images/product/pangu/system/* build/PORTROM/images/system/system/ 
#rm -rf build/PORTROM/images/product/pangu

#检查是否缺少相应的vndk


#其他机型可能没有default.prop
#vndk_version=$(< build/PORTROM/images/vendor/default.prop grep "ro.vndk.version" | awk "NR==1" | cut -d '=' -f 2)
for prop_file in $(find build/PORTROM/images/vendor/ -name "*.prop"); do
    vndk_version=$(< "$prop_file" grep "ro.vndk.version" | awk "NR==1" | cut -d '=' -f 2)
    if [ -n "$vndk_version" ]; then
        Yellow "ro.vndk.version found in $prop_file: $vndk_version"
        break  
    fi
done
baseVndk=$(find build/BASEROM/images/system_ext/apex -type f -name "com.android.vndk.v${vndk_version}.apex")
portVndk=$(find build/PORTROM/images/system_ext/apex -type f -name "com.android.vndk.v${vndk_version}.apex")

if [ ! -f "${portVndk}" ]; then
    Yellow "复制缺少的apex到目标ROM"
    cp -rf "${baseVndk}" "build/PORTROM/images/system_ext/apex/"
fi

#解决开机报错问题
targetVintf=$(find build/PORTROM/images/system_ext/etc/vintf -type f -name "manifest.xml")
if [ -f "$targetVintf" ]; then
    # Check if the file contains $vndk_version
    if grep -q "<version>$vndk_version</version>" "$targetVintf"; then
        echo "The file already contains the version $vndk_version. Skipping modification."
    else
        # If it doesn't contain $vndk_version, then add it
        ndk_version="<vendor-ndk>\n     <version>$vndk_version</version>\n </vendor-ndk>"
        sed -i "/<\/vendor-ndk>/a$ndk_version" "$targetVintf"
        echo "Version $vndk_version added to $targetVintf"
    fi
else
    echo "File $targetVintf not found."
fi
Blue "左侧挖孔灵动岛修复"
patch_smali "MiuiSystemUI.apk" "MIUIStrongToast\$2.smali" "const\/4 v7\, 0x0" "iget-object v7\, v1\, Lcom\/android\/systemui\/toast\/MIUIStrongToast;->mRLLeft:Landroid\/widget\/RelativeLayout;\\n\\tinvoke-virtual {v7}, Landroid\/widget\/RelativeLayout;->getLeft()I\\n\\tmove-result v7\\n\\tint-to-float v7,v7"

Blue "不优雅的方案解决开机软重启问题"
patch_smali "miui-services.jar" "HysteresisLevelsImpl.smali" "iget v\([0-9]\), v\([0-9]\), Lcom\/android\/server\/display\/DisplayDeviceConfig\$HighBrightnessModeData;->minimumLux:F" "const\/high16 v\1, 0x3f800000"

Blue "去除安卓14应用签名限制"
patch_smali "framework.jar" "ApkSignatureVerifier.smali" "const\/4 v0, 0x2" "const\/4 v0, 0x1" 
# 修复软重启

# 主题防恢复
if [ -f build/PORTROM/images/system/system/etc/init/hw/init.rc ];then
	sed -i '/on boot/a\'$'\n''    chmod 0731 \/data\/system\/theme' build/PORTROM/images/system/system/etc/init/hw/init.rc
fi

# 删除多余的App
rm -rf build/PORTROM/images/product/app/MSA
rm -rf build/PORTROM/images/product/priv-app/MSA
rm -rf build/PORTROM/images/product/app/mab
rm -rf build/PORTROM/images/product/priv-app/mab
rm -rf build/PORTROM/images/product/app/Updater
rm -rf build/PORTROM/images/product/priv-app/Updater
rm -rf build/PORTROM/images/product/app/MiuiUpdater
rm -rf build/PORTROM/images/product/priv-app/MiuiUpdater
rm -rf build/PORTROM/images/product/app/MIUIUpdater
rm -rf build/PORTROM/images/product/priv-app/MIUIUpdater
rm -rf build/PORTROM/images/product/app/MiService
rm -rf build/PORTROM/images/product/app/MIService
rm -rf build/PORTROM/images/product/app/SoterService
rm -rf build/PORTROM/images/product/priv-app/MiService
rm -rf build/PORTROM/images/product/priv-app/MIService
rm -rf build/PORTROM/images/product/app/*Hybrid*
rm -rf build/PORTROM/images/product/priv-app/*Hybrid*
rm -rf build/PORTROM/images/product/etc/auto-install*
rm -rf build/PORTROM/images/product/app/AnalyticsCore/*
rm -rf build/PORTROM/images/product/priv-app/AnalyticsCore/*
rm -rf build/PORTROM/images/product/data-app/*GalleryLockscreen* >/dev/null 2>&1
mkdir -p app
mv build/PORTROM/images/product/data-app/*Weather* app/ >/dev/null 2>&1
mv build/PORTROM/images/product/data-app/*DeskClock* app/ >/dev/null 2>&1
mv build/PORTROM/images/product/data-app/*Gallery* app/ >/dev/null 2>&1
mv build/PORTROM/images/product/data-app/*SoundRecorder* app/ >/dev/null 2>&1
mv build/PORTROM/images/product/data-app/*ScreenRecorder* app/ >/dev/null 2>&1
mv build/PORTROM/images/product/data-app/*Calculator* app/ >/dev/null 2>&1
mv build/PORTROM/images/product/data-app/*Calendar* app/ >/dev/null 2>&1
rm -rf build/PORTROM/images/product/data-app/*
cp -rf app/* build/PORTROM/images/product/data-app
rm -rf app
rm -rf build/PORTROM/images/system/verity_key
rm -rf build/PORTROM/images/vendor/verity_key
rm -rf build/PORTROM/images/product/verity_key
rm -rf build/PORTROM/images/system/recovery-from-boot.p
rm -rf build/PORTROM/images/vendor/recovery-from-boot.p
rm -rf build/PORTROM/images/product/recovery-from-boot.p
rm -rf build/PORTROM/images/product/media/theme/miui_mod_icons/com.google.android.apps.nbu*
rm -rf build/PORTROM/images/product/media/theme/miui_mod_icons/dynamic/com.google.android.apps.nbu*

# build.prop 修改
Blue "正在修改 build.prop"
#
#change the locale to English
export LC_ALL=en_US.UTF-8
buildDate=$(date -u +"%a %b %d %H:%M:%S UTC %Y")
buildUtc=$(date +%s)
for i in $(find build/PORTROM/images -type f -name "build.prop");do
    Blue "正在处理 ${i}"
    sed -i "s/ro.build.date=.*/ro.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.build.date.utc=.*/ro.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.odm.build.date=.*/ro.odm.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.odm.build.date.utc=.*/ro.odm.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.vendor.build.date=.*/ro.vendor.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.vendor.build.date.utc=.*/ro.vendor.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.system.build.date=.*/ro.system.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.system.build.date.utc=.*/ro.system.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.product.build.date=.*/ro.product.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.product.build.date.utc=.*/ro.product.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.system_ext.build.date=.*/ro.system_ext.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.system_ext.build.date.utc=.*/ro.system_ext.build.date.utc=${buildUtc}/g" ${i}
   
    sed -i "s/ro.product.device=.*/ro.product.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.product.name=.*/ro.product.product.name=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.odm.device=.*/ro.product.odm.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.vendor.device=.*/ro.product.vendor.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.system.device=.*/ro.product.system.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.board=.*/ro.product.board=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.system_ext.device=.*/ro.product.system_ext.device=${base_rom_code}/g" ${i}
    sed -i "s/persist.sys.timezone=.*/persist.sys.timezone=Asia\/Shanghai/g" ${i}
    sed -i "s/ro.product.mod_device=.*/ro.product.mod_device=${base_rom_code}/g" ${i}
    #全局替换device_code
    if [[ $port_mios_version_incremental != *DEV* ]];then
        sed -i "s/$port_device_code/$base_device_code/g" ${i}
    fi
    # 添加build user信息
    sed -i "s/ro.build.user=.*/ro.build.user=${BUILDUSER}/g" ${i}
    sed -i "s/ro.build.host=.*/ro.build.host=${BUILDHOST}/g" ${i}
    
done

#sed -i -e '$a\'$'\n''persist.adb.notify=0' build/PORTROM/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.usb.config=mtp,adb' build/PORTROM/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.sys.disable_rescue=true' build/PORTROM/images/system/system/build.prop
#sed -i -e '$a\'$'\n''persist.miui.extm.enable=0' build/PORTROM/images/system/system/build.prop


# 屏幕密度修修改
for prop in $(find build/BASEROM/images/product build/BASEROM/images/system -type f -name "build.prop");do
    base_rom_density=$(< "$prop" grep "ro.sf.lcd_density" |awk 'NR==1' |cut -d '=' -f 2)
    if [ "${base_rom_density}" != "" ];then
        Green "底包屏幕密度值 ${base_rom_density}"
        break 
    fi
done

# 未在底包找到则默认440,如果是其他值可自己修改
[ -z ${base_rom_density} ] && base_rom_density=440

found=0
for prop in $(find build/PORTROM/images/product build/PORTROM/images/system -type f -name "build.prop");do
    if grep -q "ro.sf.lcd_density" ${prop};then
        Blue "找到ro.fs.lcd_density，替换值为$base_rom_density" 
        sed -i "s/ro.sf.lcd_density=.*/ro.sf.lcd_density=${base_rom_density}/g" ${prop}
        found=1
    fi
    sed -i "s/persist.miui.density_v2=.*/persist.miui.density_v2=${base_rom_density}/g" ${prop}
done

if [ $found -eq 0  ]; then
        Blue "未找到ro.fs.lcd_density，build.prop新建一个值$base_rom_density"
        echo "ro.sf.lcd_density=${base_rom_density}" >> build/PORTROM/images/product/etc/build.prop
fi

echo "ro.miui.cust_erofs=0" >> build/PORTROM/images/product/etc/build.prop

#vendorprop=$(find build/PORTROM/images/vendor -type f -name "build.prop")
#odmprop=$(find build/BASEROM/images/odm -type f -name "build.prop" |awk 'NR==1')
#if [ "$(< $vendorprop grep "sys.haptic" |awk 'NR==1')" != "" ];then
#    Blue "复制 haptic prop 到 odm"
#    < $vendorprop grep "sys.haptic" >>${odmprop}
#fi

#Fix： mi10 boot stuck at the first screen
sed -i "s/persist\.sys\.millet\.cgroup1/#persist\.sys\.millet\.cgroup1/" build/PORTROM/images/vendor/build.prop
echo "ro.millet.netlink=29" >> build/PORTROM/images/vendor/build.prop

#Fix：Fingerprint issue encountered on OS V1.0.18
echo "vendor.perf.framepacing.enable=false" >> build/PORTROM/images/vendor/build.prop

#自定义替换
#Devices/机型代码/overaly 按照镜像的目录结构，可直接替换目标。
if [[ -d "devices/${base_rom_code}/overlay" ]]; then
    targetNFCFolder=$(find build/PORTROM/images/system/system build/PORTROM/images/product build/PORTROM/images/system_ext -type d -name "NQNfcNci*")
    targetCamera=$(find build/PORTROM/images/system/system build/PORTROM/images/product build/PORTROM/images/system_ext -type d -name "MiuiCamera")
    rm -rf $targetNFCFolder $targetCamera
    cp -rfv devices/${base_rom_code}/overlay/* build/PORTROM/images/
else
    Yellow "devices/${base_rom_code}/overlay 未找到"
fi

#添加erofs文件系统fstab
if [ ${packType} == "EROFS" ];then
    Yellow "检查 vendor fstab.com是否需要添加erofs挂载点"
    if ! grep -q "erofs" build/PORTROM/images/vendor/etc/fstab.qcom ; then
               for pname in system odm vendor product mi_ext system_ext; do
                     sed -i "/\/${pname}[[:space:]]\+ext4/{p;s/ext4/erofs/;}" build/PORTROM/images/vendor/etc/fstab.qcom
                     added_line=$(sed -n "/\/${pname}[[:space:]]\+erofs/p" build/PORTROM/images/vendor/etc/fstab.qcom)
    
                    if [ -n "$added_line" ]; then
                        Yellow "添加$pname"
                    else
                        Error "添加失败，请检查"
                        exit 1
                        
                    fi
                done
    fi
fi

# 去除avb校验
Blue "去除avb校验"
for fstab in $(find build/PORTROM/images/ -type f -name "fstab.*");do
    Blue "Target: $fstab"
    sed -i "s/,avb_keys=.*avbpubkey//g" $fstab
    sed -i "s/,avb=vbmeta_system//g" $fstab
    sed -i "s/,avb=vbmeta_vendor//g" $fstab
    sed -i "s/,avb=vbmeta//g" $fstab
    sed -i "s/,avb//g" $fstab
done

# data 加密
remove_data_encrypt=$(grep "remove_data_encryption" bin/port_config |cut -d '=' -f 2)
if [ ${remove_data_encrypt} = "true" ];then
    Blue "去除data加密"
    for fstab in $(find build/PORTROM/images -type f -name "fstab.*");do
		Blue "Target: $fstab"
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized+wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2+emmc_optimized+wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:aes-256-cts:v2//g" $fstab
		sed -i "s/,metadata_encryption=aes-256-xts:wrappedkey_v0//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts:wrappedkey_v0//g" $fstab
		sed -i "s/,metadata_encryption=aes-256-xts//g" $fstab
		sed -i "s/,fileencryption=aes-256-xts//g" $fstab
		sed -i "s/fileencryption/encryptable/g" $fstab
		sed -i "s/,fileencryption=ice//g" $fstab
	done
fi

for pname in ${PORT_PARTITION};do
    rm -rf build/PORTROM/images/${pname}.img
done
echo "${packType}">fstype.txt
superSize=$(bash bin/getSuperSize.sh $deviceCode)
Green "Super大小为${superSize}"
Green 开始打包镜像
for pname in ${SUPERLIST};do
    if [ -d "build/PORTROM/images/$pname" ];then
        if [[ $(uname) == "Darwin" ]];then
            thisSize=$(find build/PORTROM/images/${pname} | xargs stat -f%z | awk ' {s+=$1} END { print s }' )
        else
            thisSize=$(du -sb build/PORTROM/images/${pname} |tr -cd 0-9)
        fi
        case $pname in
            mi_ext) addSize=4194304 ;;
            odm) addSize=134217728 ;;
            system|vendor|system_ext) addSize=154217728 ;;
            product) addSize=204217728 ;;
            *) addSize=8554432 ;;
        esac
        if [ "$packType" = "EXT" ];then
            Blue "$pname"为EXT4文件系统多分配大小$addSize
            for fstab in $(find build/PORTROM/images/${pname}/ -type f -name "fstab.*");do
                #sed -i '/overlay/d' $fstab
                sed -i '/system * erofs/d' $fstab
                sed -i '/system_ext * erofs/d' $fstab
                sed -i '/vendor * erofs/d' $fstab
                sed -i '/product * erofs/d' $fstab
            done
            thisSize=$(echo "$thisSize + $addSize" |bc)
            Blue 以[$packType]文件系统打包[${pname}.img]大小[$thisSize]
            python3 bin/fspatch.py build/PORTROM/images/${pname} build/PORTROM/config/${pname}_fs_config
            python3 bin/contextpatch.py build/PORTROM/images/${pname} build/PORTROM/config/${pname}_file_contexts
            make_ext4fs -J -T $(date +%s) -S build/PORTROM/config/${pname}_file_contexts -l $thisSize -C build/PORTROM/config/${pname}_fs_config -L ${pname} -a ${pname} build/PORTROM/images/${pname}.img build/PORTROM/images/${pname}

            if [ -f "build/PORTROM/images/${pname}.img" ];then
                Green "成功以大小 [$thisSize] 打包 [${pname}.img] [${packType}] 文件系统"
                #rm -rf build/BASEROM/images/${pname}
            else
                Error "以 [${packType}] 文件系统打包 [${pname}] 分区失败"
            fi
        else
            
                Blue 以[$packType]文件系统打包[${pname}.img]
                python3 bin/fspatch.py build/PORTROM/images/${pname} build/PORTROM/config/${pname}_fs_config
                python3 bin/contextpatch.py build/PORTROM/images/${pname} build/PORTROM/config/${pname}_file_contexts
                #sudo perl -pi -e 's/\\@/@/g' build/PORTROM/config/${pname}_file_contexts
                mkfs.erofs --mount-point ${pname} --fs-config-file build/PORTROM/config/${pname}_fs_config --file-contexts build/PORTROM/config/${pname}_file_contexts build/PORTROM/images/${pname}.img build/PORTROM/images/${pname}
                if [ -f "build/PORTROM/images/${pname}.img" ];then
                    Green "成功以 [erofs] 文件系统打包 [${pname}.img]"
                    #rm -rf build/PORTROM/images/${pname}
                else
                    Error "以 [${packType}] 文件系统打包 [${pname}] 分区失败"
                    exit 1
                fi
        fi
        unset fsType
        unset thisSize
    fi
done
rm fstype.txt

# 打包 super.img

if [ "${baseROMType}" = "br" ];then
    Blue "打包A-only super.img"
    lpargs="-F --output build/PORTROM/images/super.img --metadata-size 65536 --super-name super --metadata-slots 2 --block-size 4096 --device super:$superSize --group=qti_dynamic_partitions:$superSize"
    for pname in odm mi_ext system system_ext product vendor;do
        if [ -f "build/PORTROM/images/${pname}.img" ];then
            if [[ $(uname) == "Darwin" ]];then
               subsize=$(find build/PORTROM/images/${pname}.img | xargs stat -f%z | awk ' {s+=$1} END { print s }')
            else
                subsize=$(du -sb build/PORTROM/images/${pname}.img |tr -cd 0-9)
            fi
            Green Super 子分区 [$pname] 大小 [$subsize]
            args="--partition ${pname}:none:${subsize}:qti_dynamic_partitions --image ${pname}=build/PORTROM/images/${pname}.img"
            lpargs="$lpargs $args"
            unset subsize
            unset args
        fi
    done
else
    Blue "打包V-A/B机型 super.img"
    lpargs="-F --virtual-ab --output build/PORTROM/images/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:$superSize --group=qti_dynamic_partitions_a:$superSize --group=qti_dynamic_partitions_b:$superSize"

    for pname in ${SUPERLIST};do
        if [ -f "build/PORTROM/images/${pname}.img" ];then
            subsize=$(du -sb build/PORTROM/images/${pname}.img |tr -cd 0-9)
            Green Super 子分区 [$pname] 大小 [$subsize]
            args="--partition ${pname}_a:none:${subsize}:qti_dynamic_partitions_a --image ${pname}_a=build/PORTROM/images/${pname}.img --partition ${pname}_b:none:0:qti_dynamic_partitions_b"
            lpargs="$lpargs $args"
            unset subsize
            unset args
        fi
    done
fi
lpmake $lpargs
echo "lpmake $lpargs"
if [ -f "build/PORTROM/images/super.img" ];then
    Green 成功打包 super.img
else
    Error 无法打包 super.img
    exit 1
fi
for pname in ${SUPERLIST};do
    rm -rf build/PORTROM/images/${pname}.img
done

Blue "正在压缩 super.img"
zstd --rm build/PORTROM/images/super.img -o build/PORTROM/images/super.zst




mkdir -p out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/

Blue "正在生成刷机脚本"
if [ "${baseROMType}" = "br" ];then

    mv -f build/PORTROM/images/super.zst out/hyperos_${deviceCode}_${port_rom_version}/
    #firmware
    if [ -d build/BASEROM/firmware-update ];then
        mkdir -p out/hyperos_${deviceCode}_${port_rom_version}/firmware-update
        cp -rf build/BASEROM/firmware-update/*  out/hyperos_${deviceCode}_${port_rom_version}/firmware-update
    fi
        # disable vbmeta
    for img in $(find out/hyperos_${deviceCode}_${port_rom_version}/firmware-update -type f -name "vbmeta*.img");do
        python3 bin/patch-vbmeta.py ${img}
    done
    mv -f build/BASEROM/boot.img out/hyperos_${deviceCode}_${port_rom_version}/boot_official.img
    cp -rf bin/flash/a-only/update-binary out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/
    cp -rf bin/flash/zstd out/hyperos_${deviceCode}_${port_rom_version}/META-INF/
    cp devices/$base_rom_code/boot_tv.img out/hyperos_${deviceCode}_${port_rom_version}/
    sed -i "s/portversion/${port_rom_version}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/baseversion/${base_rom_version}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/andVersion/${port_android_version}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/deviceCode/${base_rom_code}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary

else
    mkdir -p out/hyperos_${deviceCode}_${port_rom_version}/images/
    mv -f build/PORTROM/images/super.zst out/hyperos_${deviceCode}_${port_rom_version}/images/
    cp -rf bin/flash/vab/update-binary out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/
    cp -rf bin/flash/vab/platform-tools-windows out/hyperos_${deviceCode}_${port_rom_version}/META-INF/
    cp -rf bin/flash/vab/flash_update.bat out/hyperos_${deviceCode}_${port_rom_version}/
    cp -rf bin/flash/vab/flash_and_format.bat out/hyperos_${deviceCode}_${port_rom_version}/
   
    cp -rf bin/flash/zstd out/hyperos_${deviceCode}_${port_rom_version}/META-INF/
    for fwImg in $(ls out/hyperos_${deviceCode}_${port_rom_version}/images/ |cut -d "." -f 1 |grep -vE "super|cust|preloader");do
        if [ "$(echo $fwImg |grep vbmeta)" != "" ];then
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_b images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_a images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_b images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_and_format.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_a images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_and_format.bat
            sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_b\"" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
            sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_a\"" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
        else
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_b images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_a images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_update.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_b images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_and_format.bat
            sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_a images\/"$fwImg".img" out/hyperos_${deviceCode}_${port_rom_version}/flash_and_format.bat
            sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_b\"" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
            sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_a\"" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
        fi
    done

    sed -i "s/portversion/${port_rom_version}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/baseversion/${base_rom_version}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/andVersion/${port_android_version}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    sed -i "s/deviceCode/${base_rom_code}/g" out/hyperos_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary

    busybox unix2dos out/hyperos_${deviceCode}_${port_rom_version}/flash_update.bat
    busybox unix2dos out/hyperos_${deviceCode}_${port_rom_version}/flash_and_format.bat

fi

find out/hyperos_${deviceCode}_${port_rom_version} |xargs touch
cd out/hyperos_${deviceCode}_${port_rom_version}/ || exit
zip -r hyperos_${deviceCode}_${port_rom_version}.zip ./*
mv hyperos_${deviceCode}_${port_rom_version}.zip ../
cd ../  

hash=$(md5sum hyperos_${deviceCode}_${port_rom_version}.zip |head -c 10)
mv hyperos_${deviceCode}_${port_rom_version}.zip hyperos_${deviceCode}_${port_rom_version}_${hash}_${port_android_version}_ROOT_${packType}.zip
Green "移植完毕"    
Green "输出包为 $(pwd)/hyperos_${deviceCode}_${port_rom_version}_${hash}_${port_android_version}_ROOT_${packType}.zip"