# miui_port project

# Only For V-A/B Device

# Based on Android 13

# Test Base ROM: Mi 10S (V14.0.6)

# Test Port ROM: Mi13、Mi13Pro、Mi13Ultra

# 底包和移植包为外部参数传入
BASEROM="$1"
PORTROM="$2"

export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# 定义颜色输出函数
Error() {
    echo -e \[$(date +%m%d-%T)\] "\e[1;31m"$@"\e[0m"
}

Yellow() {
	echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"
}

Green() {
	echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"
}

# 移植的分区，可在 bin/port_config 中更改
PORT_PARTITION=$(grep "partition_to_port" bin/port_config |cut -d '=' -f 2)
SUPERLIST=$(grep "super_list" bin/port_config |cut -d '=' -f 2)
REPACKEXT4=$(grep "repack_with_ext4" bin/port_config |cut -d '=' -f 2)

# 检查为本地包还是链接
if [ ! -f "${BASEROM}" ] && [ "$(echo $BASEROM |grep http)" != "" ];then
    Yellow "底包为一个链接，正在尝试下载"
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
    Yellow "移植包为一个链接，正在尝试下载"
    aria2c --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 ${PORTROM}
    BASEROM=$(basename ${PORTROM})
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



# 检查ROM为包含 payload.bin 的包，否则无法处理
Yellow "正在检测ROM包"
unzip -l ${BASEROM}|grep "payload.bin" 1>/dev/null 2>&1 ||Error "底包没有payload.bin，请用MIUI官方包作为底包"
unzip -l ${BASEROM} |grep "payload.bin" 1>/dev/null 2>&1 ||Error "目标移植包没有payload.bin，请用MIUI官方包作为移植包"

Green "ROM初步检测通过"


# 清理文件
Yellow "正在清理文件"
for i in ${PORT_PARTITION};do
    [ -d ./${i} ] && rm -rf ./${i}
done
rm -rf app
rm -rf config
rm -rf BASEROM/
rm -rf PORTROM/
find . -type d -name 'PORT_*' |xargs rm -rf
mkdir -p BASEROM/images/
mkdir -p BASEROM/config/
mkdir -p PORTROM/images/
Green "文件清理完毕"


# 提取分区
Yellow "正在提取底包 [payload.bin]"
unzip ${BASEROM} payload.bin -d BASEROM ||Error "解压底包 [payload.bin] 时出错"
Green "底包 [payload.bin] 提取完毕"
Yellow "正在提取移植包 [payload.bin]"
unzip ${PORTROM} payload.bin -d PORTROM ||Error "解压移植包 [payload.bin] 时出错"
Green "移植包 [payload.bin] 提取完毕"

Yellow "开始分解底包 [payload.bin]"
payload-dumper-go -o BASEROM/images/ BASEROM/payload.bin >/dev/null 2>&1 ||Error "分解底包 [payload.bin] 时出错"


for part in ${PORT_PARTITION};do
    payload-dumper-go -l PORTROM/payload.bin  |sed "s/,/\n/g" |grep -v "vbmeta" |grep "${part} ("
    if [ $? -eq 0 ];then
        Yellow "底包 [${part}.img] 已重命名为 [${part}_bak.img]"
        mv BASEROM/images/${part}.img BASEROM/images/${part}_bak.img
        Yellow "正在分解底包 [${part}_bak.img]"
        python3 bin/imgextractor/imgextractor.py BASEROM/images/${part}_bak.img 2>/dev/null
        if [ -d "${part}_bak" ];then
            mv ${part}_bak BASEROM/images/
            sed -i '/+found/d' config/${part}_bak_file_contexts
            rm -rf BASEROM/images/${part}_bak.img
        else
            extract.erofs -x -i BASEROM/images/${part}_bak.img
            mv ${part}_bak BASEROM/images/
            rm -rf BASEROM/images/${part}_bak.img
        fi
        mv config/${part}_bak_size.txt BASEROM/config/
        mv config/${part}_bak_fs_config BASEROM/config/
        mv config/${part}_bak_file_contexts BASEROM/config/
        Yellow "正在提取移植包 [${part}] 分区"
        payload-dumper-go -p ${part} -o BASEROM/images/ PORTROM/payload.bin >/dev/null 2>&1 ||Error "提取移植包 [${part}] 分区时出错"
    fi
done

rm -rf PORTROM

# 分解镜像
Green 开始提取逻辑分区镜像
for pname in ${SUPERLIST};do
    if [ -f "BASEROM/images/${pname}.img" ];then
        Yellow 正在提取 ${pname}.img
        python3 bin/imgextractor/imgextractor.py BASEROM/images/${pname}.img 2>/dev/null
        if [ -d "${pname}" ];then
            mv ${pname} BASEROM/images/
            mv config/*${pname}* BASEROM/config/
            sed -i '/+found/d' BASEROM/config/${pname}_file_contexts
            rm -rf BASEROM/images/${pname}.img
            # 测试原包分区文件系统类型
            if [ "${pname}" == "vendor" ];then
                packType=ext4
                Green "底包为 [ext4] 文件系统"
            fi
        else
            extract.erofs -x -i BASEROM/images/${pname}.img
            mv ${pname} BASEROM/images/
            mv config/*${pname}* BASEROM/config/
            rm -rf BASEROM/images/${pname}.img
            # 测试原包分区文件系统类型
            if [ "${pname}" == "vendor" ];then
                packType=erofs
                Green "底包为 [erofs] 文件系统"
                [ "${REPACKEXT4}" == "true" ] && packType=ext4
            fi
        fi
        Green "提取 [${pname}] 镜像完毕"
    fi
done
rm -rf config


# 获取ROM参数

Yellow "正在获取ROM参数"
# 安卓版本
base_android_version=$(cat BASEROM/images/vendor/build.prop |grep "ro.vendor.build.version.release" |awk 'NR==1' |cut -d '=' -f 2)
port_android_version=$(cat BASEROM/images/system/system/build.prop |grep "ro.system.build.version.release" |awk 'NR==1' |cut -d '=' -f 2)
Green "安卓版本: 底包为[Android ${base_android_version}], 移植包为 [Android ${port_android_version}]"

# SDK版本
base_android_sdk=$(cat BASEROM/images/vendor/build.prop |grep "ro.vendor.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
port_android_sdk=$(cat BASEROM/images/system/system/build.prop |grep "ro.system.build.version.sdk" |awk 'NR==1' |cut -d '=' -f 2)
Green "SDK 版本: 底包为 [SDK ${base_android_sdk}], 移植包为 [SDK ${port_android_sdk}]"

# ROM版本
base_rom_version=$(cat BASEROM/images/vendor/build.prop |grep "ro.vendor.build.version.incremental" |awk 'NR==1' |cut -d '=' -f 2)
port_rom_version=$(cat BASEROM/images/system/system/build.prop |grep "ro.system.build.version.incremental" |awk 'NR==1' |cut -d '=' -f 2)
Green "ROM 版本: 底包为 [${base_rom_version}], 移植包为 [${port_rom_version}]"

# MIUI版本
base_miui_version=$(cat BASEROM/images/product_bak/etc/build.prop |grep "ro.miui.ui.version.code" |awk 'NR==1' |cut -d '=' -f 2)
port_miui_version=$(cat BASEROM/images/product/etc/build.prop |grep "ro.miui.ui.version.code" |awk 'NR==1' |cut -d '=' -f 2)
Green "MIUI版本: 底包为 [${base_miui_version}], 移植包为 [${port_miui_version}]"

# 代号
base_rom_code=$(cat BASEROM/images/vendor/build.prop |grep "ro.product.vendor.device" |awk 'NR==1' |cut -d '=' -f 2)
port_rom_code=$(cat BASEROM/images/system/system/build.prop |grep "ro.product.system.device" |awk 'NR==1' |cut -d '=' -f 2)
Green "机型代号: 底包为 [${base_rom_code}], 移植包为 [${port_rom_code}]"

# 机型名称
base_rom_marketname=$(cat BASEROM/images/vendor/build.prop |grep "ro.product.vendor.marketname" |awk 'NR==1' |cut -d '=' -f 2)
port_rom_marketname=$(cat BASEROM/images/system/system/build.prop |grep "ro.product.system.marketname" |awk 'NR==1' |cut -d '=' -f 2)  # 这个很可能是空的
Green "机型名称: 底包为 [${base_rom_marketname}], 移植包为 [${port_rom_marketname}]"

# 修改ROM包

# 去除avb校验
Yellow "去除avb校验"
for fstab in $(find BASEROM/images/ -type f -name "fstab.*");do
    Yellow "Target: $fstab"
    sed -i "s/,avb_keys=.*avbpubkey//g" $fstab
    sed -i "s/,avb=vbmeta_system//g" $fstab
    sed -i "s/,avb=vbmeta_vendor//g" $fstab
    sed -i "s/,avb=vbmeta//g" $fstab
    sed -i "s/,avb//g" $fstab
done

# data 加密
remove_data_encrypt=$(grep "remove_data_encryption" bin/port_config |cut -d '=' -f 2)
if [ "${remove_data_encrypt}" == "true" ];then
    Yellow "去除data加密"
    for fstab in $(find BASEROM/images/ -type f -name "fstab.*");do
		Yellow "Target: $fstab"
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

baseAospFrameworkResOverlay=$(find BASEROM/images/product_bak/ -type f -name "AospFrameworkResOverlay.apk")
portAospFrameworkResOverlay=$(find BASEROM/images/product/ -type f -name "AospFrameworkResOverlay.apk")
if [ -f "${baseAospFrameworkResOverlay}" ] && [ -f "${portAospFrameworkResOverlay}" ];then
    Yellow "正在替换 [AospFrameworkResOverlay.apk]"
    cp -rf ${baseAospFrameworkResOverlay} ${portAospFrameworkResOverlay}
fi

baseMiuiFrameworkResOverlay=$(find BASEROM/images/product_bak/ -type f -name "MiuiFrameworkResOverlay.apk")
portMiuiFrameworkResOverlay=$(find BASEROM/images/product/ -type f -name "MiuiFrameworkResOverlay.apk")
if [ -f "${baseMiuiFrameworkResOverlay}" ] && [ -f "${portMiuiFrameworkResOverlay}" ];then
    Yellow "正在替换 [MiuiFrameworkResOverlay.apk]"
    cp -rf ${baseMiuiFrameworkResOverlay} ${portMiuiFrameworkResOverlay}
fi

baseAospWifiResOverlay=$(find BASEROM/images/product_bak/ -type f -name "AospWifiResOverlay.apk")
portAospWifiResOverlay=$(find BASEROM/images/product/ -type f -name "AospWifiResOverlay.apk")
if [ -f "${baseAospWifiResOverlay}" ] && [ -f "${portAospWifiResOverlay}" ];then
    Yellow "正在替换 [AospWifiResOverlay.apk]"
    cp -rf ${baseAospWifiResOverlay} ${portAospWifiResOverlay}
fi

baseDevicesAndroidOverlay=$(find BASEROM/images/product_bak/ -type f -name "DevicesAndroidOverlay.apk")
portDevicesAndroidOverlay=$(find BASEROM/images/product/ -type f -name "DevicesAndroidOverlay.apk")
if [ -f "${baseDevicesAndroidOverlay}" ] && [ -f "${portDevicesAndroidOverlay}" ];then
    Yellow "正在替换 [DevicesAndroidOverlay.apk]"
    cp -rf ${baseDevicesAndroidOverlay} ${portDevicesAndroidOverlay}
fi

baseDevicesOverlay=$(find BASEROM/images/product_bak/ -type f -name "DevicesOverlay.apk")
portDevicesOverlay=$(find BASEROM/images/product/ -type f -name "DevicesOverlay.apk")
if [ -f "${baseDevicesOverlay}" ] && [ -f "${portDevicesOverlay}" ];then
    Yellow "正在替换 [DevicesOverlay.apk]"
    cp -rf ${baseDevicesOverlay} ${portDevicesOverlay}
fi

baseMiuiBiometricResOverlay=$(find BASEROM/images/product_bak/ -type f -name "MiuiBiometricResOverlay.apk")
portMiuiBiometricResOverlay=$(find BASEROM/images/product/ -type f -name "MiuiBiometricResOverlay.apk")
if [ -f "${baseMiuiBiometricResOverlay}" ] && [ -f "${portMiuiBiometricResOverlay}" ];then
    Yellow "正在替换 [MiuiBiometricResOverlay.apk]"
    cp -rf ${baseMiuiBiometricResOverlay} ${portMiuiBiometricResOverlay}
fi

# radio lib
# Yellow "信号相关"
# for radiolib in $(find BASEROM/images/system_bak/system/lib/ -maxdepth 1 -type f -name "*radio*");do
#     cp -rf $radiolib BASEROM/images/system/system/lib/
# done

# for radiolib in $(find BASEROM/images/system_bak/system/lib64/ -maxdepth 1 -type f -name "*radio*");do
#     cp -rf $radiolib BASEROM/images/system/system/lib64/
# done


# audio lib
# Yellow "音频相关"
# for audiolib in $(find BASEROM/images/system_bak/system/lib/ -maxdepth 1 -type f -name "*audio*");do
#     cp -rf $audiolib BASEROM/images/system/system/lib/
# done

# for audiolib in $(find BASEROM/images/system_bak/system/lib64/ -maxdepth 1 -type f -name "*audio*");do
#     cp -rf $audiolib BASEROM/images/system/system/lib64/
# done

# # bt lib
# Yellow "蓝牙相关"
# for btlib in $(find BASEROM/images/system_bak/system/lib/ -maxdepth 1 -type f -name "*bluetooth*");do
#     cp -rf $btlib BASEROM/images/system/system/lib/
# done

# for btlib in $(find BASEROM/images/system_bak/system/lib64/ -maxdepth 1 -type f -name "*bluetooth*");do
#     cp -rf $btlib BASEROM/images/system/system/lib64/
# done


# displayconfig id
Yellow "正在替换 displayconfig"
rm -rf BASEROM/images/product/etc/displayconfig/*
cp -rf BASEROM/images/product_bak/etc/displayconfig/* BASEROM/images/product/etc/displayconfig/
for context in $(find BASEROM/images/product/etc/displayconfig/ -type f);do
    echo>>BASEROM/config/product_file_contexts
    echo>>BASEROM/config/product_fs_config
    echo "${context} u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/product_file_contexts
    echo "${context} 0 0 0644" |sed 's/BASEROM\/images\///g' >>BASEROM/config/product_fs_config
done

# device_features
Yellow "正在替换 device_features"
rm -rf BASEROM/images/product/etc/device_features/*
cp -rf BASEROM/images/product_bak/etc/device_features/* BASEROM/images/product/etc/device_features/
for context in $(find BASEROM/images/product/etc/device_features/ -type f);do
    echo>>BASEROM/config/product_file_contexts
    echo>>BASEROM/config/product_fs_config
    echo "${context} u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/product_file_contexts
    echo "${context} 0 0 0644" |sed 's/BASEROM\/images\///g' >>BASEROM/config/product_fs_config
done


# 相机
baseMiuiCamera=$(find BASEROM/images/product_bak/ -type d -name "MiuiCamera")
portMiuiCamera=$(find BASEROM/images/product/ -type d -name "MiuiCamera")
if [ -d "${baseMiuiCamera}" ] && [ -d "${portMiuiCamera}" ];then
    Yellow "正在替换 相机"
    rm -rf ./${portMiuiCamera}/*
    cp -rf ./${baseMiuiCamera}/* ${portMiuiCamera}/
fi


# MiSound
baseMiSound=$(find BASEROM/images/product_bak/ -type d -name "MiSound")
portMiSound=$(find BASEROM/images/product/ -type d -name "MiSound")
if [ -d "${baseMiSound}" ] && [ -d "${portMiSound}" ];then
    Yellow "正在替换 MiSound"
    rm -rf ./${portMiSound}/*
    cp -rf ./${baseMiSound}/* ${portMiSound}/
fi

# MusicFX
baseMusicFX=$(find BASEROM/images/product_bak/ BASEROM/images/system_bak/ -type d -name "MusicFX")
portMusicFX=$(find BASEROM/images/product/ BASEROM/images/system/ -type d -name "MusicFX")
if [ -d "${baseMusicFX}" ] && [ -d "${portMusicFX}" ];then
    Yellow "正在替换 MusicFX"
    rm -rf ./${portMusicFX}/*
    cp -rf ./${baseMusicFX}/* ${portMusicFX}/
fi

# 人脸
baseMiuiBiometric=$(find BASEROM/images/product_bak/app -type d -name "MiuiBiometric*")
portMiuiBiometric=$(find BASEROM/images/product/app -type d -name "MiuiBiometric*")
if [ -d "${baseMiuiBiometric}" ] && [ -d "${portMiuiBiometric}" ];then
    Yellow "正在替换人脸识别"
    rm -rf ./${portMiuiBiometric}/*
    cp -rf ./${baseMiuiBiometric}/* ${portMiuiBiometric}/
else
    if [ -d "${baseMiuiBiometric}" ] && [ ! -d "${portMiuiBiometric}" ];then
        Yellow "Port MiuiBiometric not found, copying..."
        cp -rf ${baseMiuiBiometric} BASEROM/images/product/app/
    fi
fi


# 修复NFC
Yellow "正在修复 NFC"
cp -rf BASEROM/images/product_bak/pangu/system ./system
for file in $(find system -type d |sed "1d");do
    echo>>BASEROM/config/system_file_contexts
    echo>>BASEROM/config/system_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/system\//\/system\/system\//g' |sed 's/\./\\\./g' >>BASEROM/config/system_file_contexts
    echo "$file 0 0 0755" |sed 's/system/system\/system/g' >>BASEROM/config/system_fs_config
done

for file in $(find system/ -type f);do
    echo>>BASEROM/config/system_file_contexts
    echo>>BASEROM/config/system_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/system\//\/system\/system\//g' |sed 's/\./\\\./g' >>BASEROM/config/system_file_contexts
    echo "$file 0 0 0644" |sed 's/system/system\/system/g' >>BASEROM/config/system_fs_config
done
cp -rf system/* BASEROM/images/system/system/
rm -rf system/
if [ -f BASEROM/images/system_bak/system/etc/permissions/com.android.nfc_extras.xml ] && [ -f BASEROM/images/system/system/etc/permissions/com.android.nfc_extras.xml ];then
    cp -rf BASEROM/images/system_bak/system/etc/permissions/com.android.nfc_extras.xml BASEROM/images/system/system/etc/permissions/com.android.nfc_extras.xml
fi
if [ -f BASEROM/images/system_bak/system/framework/com.android.nfc_extras.jar ] && [ -f BASEROM/images/system/system/framework/com.android.nfc_extras.jar ];then
    cp -rf BASEROM/images/system_bak/system/framework/com.android.nfc_extras.jar BASEROM/images/system/system/framework/com.android.nfc_extras.jar
fi


# App context 修复
Yellow "正在补全 contexts"
for file in $(find BASEROM/images/system/system/app BASEROM/images/system/system/priv-app -type d);do
    echo>>BASEROM/config/system_file_contexts
    echo>>BASEROM/config/system_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/system_file_contexts
    echo "$file 0 0 0755" |sed 's/BASEROM\/images\///g' >>BASEROM/config/system_fs_config
done

for file in $(find BASEROM/images/system/system/app BASEROM/images/system/system/priv-app -type f);do
    echo>>BASEROM/config/system_file_contexts
    echo>>BASEROM/config/system_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/system_file_contexts
    echo "$file 0 0 0644" |sed 's/BASEROM\/images\///g' >>BASEROM/config/system_fs_config
done

for file in $(find BASEROM/images/product/app BASEROM/images/product/priv-app -type d);do
    echo>>BASEROM/config/product_file_contexts
    echo>>BASEROM/config/product_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/product_file_contexts
    echo "$file 0 0 0755" |sed 's/BASEROM\/images\///g' >>BASEROM/config/product_fs_config
done

for file in $(find BASEROM/images/product/app BASEROM/images/product/priv-app -type f);do
    echo>>BASEROM/config/product_file_contexts
    echo>>BASEROM/config/product_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/product_file_contexts
    echo "$file 0 0 644" |sed 's/BASEROM\/images\///g' >>BASEROM/config/product_fs_config
done


# lib file u:object_r:system_lib_file:s0

for lib in $(find BASEROM/images/system/system/lib/ BASEROM/images/system/system/lib64/ -maxdepth 1 -type f);do
    echo>>BASEROM/config/system_file_contexts
    echo>>BASEROM/config/system_fs_config
    echo "$lib u:object_r:system_lib_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/system_file_contexts
    echo "$lib 0 0 0644" |sed 's/BASEROM\/images\///g' >>BASEROM/config/system_fs_config
done

cp -rf BASEROM/images/product_bak/overlay/* BASEROM/images/product/overlay/
for file in $(find BASEROM/images/product/overlay -type d);do
    echo>>BASEROM/config/product_file_contexts
    echo>>BASEROM/config/product_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/product_file_contexts
    echo "$file 0 0 0755" |sed 's/BASEROM\/images\///g' >>BASEROM/config/product_fs_config
done

for file in $(find BASEROM/images/product/overlay -type f);do
    echo>>BASEROM/config/product_file_contexts
    echo>>BASEROM/config/product_fs_config
    echo "$file u:object_r:system_file:s0" |sed 's/BASEROM\/images//g' |sed 's/\./\\\./g' >>BASEROM/config/product_file_contexts
    echo "$file 0 0 644" |sed 's/BASEROM\/images\///g' >>BASEROM/config/product_fs_config
done

# 签名验证
frameworkjar=$(find BASEROM/images/system/system -type f -name framework.jar)
if [ -f "$frameworkjar" ] && [ ${port_android_version} -ge 13 ];then
	Yellow "正在去除安卓应用签名限制"
	rm -rf tmp/framework/
	mkdir -p tmp/framework/
	cp -rf ${frameworkjar} tmp/framework/framework.jar
	7z x -y tmp/framework/framework.jar *.dex -otmp/framework >/dev/null
	for dexfile in $(ls tmp/framework/*.dex);do
		echo I: Baksmaling ${dexfile}...
		fname=${dexfile%%.*}
		fname=$(echo $fname |cut -d "/" -f 3)
		java -jar bin/apktool/baksmali.jar d --api ${port_android_sdk} ${dexfile} -o tmp/framework/${fname}
		rm -rf ${dexfile}
	done
	targetSmali=$(find tmp/framework/ -type f -name ApkSignatureVerifier.smali)
	if [ -f "$targetSmali" ];then
		echo I: Target ${targetSmali}
		targetdir=$(echo $targetSmali |cut -d "/" -f 3)
		sed -i "s/const\/4 v0, 0x2/const\/4 v0, 0x1/g" $targetSmali
		rm -rf ${frameworkjar}
		echo I: Smaling smali_${targetdir} folder into ${targetdir}.dex
		java -jar bin/apktool/smali.jar a --api ${port_android_sdk} tmp/framework/${targetdir} -o tmp/framework/${targetdir}.dex
		cd tmp/framework/
		7z a -y framework.jar ${targetdir}.dex >/dev/null
		cd ../../
		cp -rf tmp/framework/framework.jar ${frameworkjar}
		rm -rf tmp/framework/
		mkdir -p tmp/framework/arm tmp/framework/arm64
		mv BASEROM/images/system/system/framework/boot-framework.vdex tmp/framework/
		mv BASEROM/images/system/system/framework/arm/boot-framework.* tmp/framework/arm/
		mv BASEROM/images/system/system/framework/arm64/boot-framework.* tmp/framework/arm64/
		rm -rf BASEROM/images/system/system/framework/*.vdex BASEROM/images/system/system/framework/arm/* BASEROM/images/system/system/framework/arm64/*
		find BASEROM/images/system -type d -name "oat" |xargs rm -rf
		find BASEROM/images/vendor -type d -name "oat" |xargs rm -rf
		find BASEROM/images/system_ext -type d -name "oat" |xargs rm -rf
		find BASEROM/images/product -type d -name "oat" |xargs rm -rf
		mv tmp/framework/* BASEROM/images/system/system/framework/
		rm -rf tmp/
	else
		echo I: Skipping modify framework.jar
		rm -rf tmp/
	fi
else
	echo I: Skipping modify framework.jar
fi


# 主题防恢复
if [ -f BASEROM/images/system/system/etc/init/hw/init.rc ];then
	sed -i '/on boot/a\    chmod 0731 \/data\/system\/theme' BASEROM/images/system/system/etc/init/hw/init.rc
fi

# 删除多余的App
rm -rf BASEROM/images/product/app/MSA
rm -rf BASEROM/images/product/priv-app/MSA
rm -rf BASEROM/images/product/app/mab
rm -rf BASEROM/images/product/priv-app/mab
rm -rf BASEROM/images/product/app/Updater
rm -rf BASEROM/images/product/priv-app/Updater
rm -rf BASEROM/images/product/app/MiuiUpdater
rm -rf BASEROM/images/product/priv-app/MiuiUpdater
rm -rf BASEROM/images/product/app/MIUIUpdater
rm -rf BASEROM/images/product/priv-app/MIUIUpdater
rm -rf BASEROM/images/product/app/MiService
rm -rf BASEROM/images/product/app/MIService
rm -rf BASEROM/images/product/priv-app/MiService
rm -rf BASEROM/images/product/priv-app/MIService
rm -rf BASEROM/images/product/app/*Hybrid*
rm -rf BASEROM/images/product/priv-app/*Hybrid*
rm -rf BASEROM/images/product/etc/auto-install*
rm -rf BASEROM/images/product/app/AnalyticsCore/*
rm -rf BASEROM/images/product/priv-app/AnalyticsCore/*
rm -rf BASEROM/images/product/data-app/*GalleryLockscreen* >/dev/null 2>&1
mkdir -p app
mv BASEROM/images/product/data-app/*Weather* app/ >/dev/null 2>&1
mv BASEROM/images/product/data-app/*DeskClock* app/ >/dev/null 2>&1
mv BASEROM/images/product/data-app/*Gallery* app/ >/dev/null 2>&1
mv BASEROM/images/product/data-app/*SoundRecorder* app/ >/dev/null 2>&1
mv BASEROM/images/product/data-app/*ScreenRecorder* app/ >/dev/null 2>&1
mv BASEROM/images/product/data-app/*Calculator* app/ >/dev/null 2>&1
mv BASEROM/images/product/data-app/*Calendar* app/ >/dev/null 2>&1
rm -rf BASEROM/images/product/data-app/*
cp -rf app/* BASEROM/images/product/data-app
rm -rf app
rm -rf BASEROM/images/system/verity_key
rm -rf BASEROM/images/vendor/verity_key
rm -rf BASEROM/images/product/verity_key
rm -rf BASEROM/images/system/recovery-from-boot.p
rm -rf BASEROM/images/vendor/recovery-from-boot.p
rm -rf BASEROM/images/product/recovery-from-boot.p
rm -rf BASEROM/images/product/media/theme/miui_mod_icons/com.google.android.apps.nbu*
rm -rf BASEROM/images/product/media/theme/miui_mod_icons/dynamic/com.google.android.apps.nbu*

# build.prop 修改
Yellow "正在修改 build.prop"
buildDate=$(date -u +"%a %b %d %H:%M:%S UTC %Y")
buildUtc=$(date +%s)
for i in $(find BASEROM/images/ -type f -name "build.prop");do
    Yellow "正在处理 ${i}"
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
    sed -i "s/ro.build.date=.*/ro.build.date=${buildDate}/g" ${i}
    sed -i "s/ro.build.date.utc=.*/ro.build.date.utc=${buildUtc}/g" ${i}
    sed -i "s/ro.odm.build.version.incremental=.*/ro.odm.build.version.incremental=${port_rom_version}/g" ${i}
    sed -i "s/ro.vendor.build.version.incremental=.*/ro.vendor.build.version.incremental=${port_rom_version}/g" ${i}
    sed -i "s/ro.system.build.version.incremental=.*/ro.system.build.version.incremental=${port_rom_version}/g" ${i}
    sed -i "s/ro.product.build.version.incremental=.*/ro.product.build.version.incremental=${port_rom_version}/g" ${i}
    sed -i "s/ro.system_ext.build.version.incremental=.*/ro.system_ext.build.version.incremental=${port_rom_version}/g" ${i}
    sed -i "s/ro.product.device=.*/ro.product.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.odm.device=.*/ro.product.odm.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.vendor.device=.*/ro.product.vendor.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.system.device=.*/ro.product.system.device=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.board=.*/ro.product.board=${base_rom_code}/g" ${i}
    sed -i "s/ro.product.system_ext.device=.*/ro.product.system_ext.device=${base_rom_code}/g" ${i}
    sed -i "s/persist.sys.timezone=.*/persist.sys.timezone=Asia\/Shanghai/g" ${i}
    sed -i "s/ro.product.mod_device=.*/ro.product.mod_device=${base_rom_code}/g" ${i}
done

sed -i '$a\persist.adb.notify=0' BASEROM/images/system/system/build.prop
sed -i '$a\persist.sys.usb.config=mtp,adb' BASEROM/images/system/system/build.prop
sed -i '$a\persist.sys.disable_rescue=true' BASEROM/images/system/system/build.prop
sed -i '$a\persist.miui.extm.enable=0' BASEROM/images/system/system/build.prop

# 屏幕密度修修改
for prop in $(find BASEROM/images/product_bak BASEROM/images/system_bak -type f -name "build.prop");do
    base_rom_density=$(cat $prop |grep "ro.sf.lcd_density" |awk 'NR==1' |cut -d '=' -f 2)
    if [ "${base_rom_density}" != "" ];then
        Green "底包屏幕密度值 ${base_rom_density}"
        break
    fi
done

# 未在底包找到则默认440,如果是其他值可自己修改
[ -z ${base_rom_density} ] && base_rom_density=440

for prop in $(find BASEROM/images/product_bak BASEROM/images/system_bak -type f -name "build.prop");do
    sed -i "s/ro.sf.lcd_density=.*/ro.sf.lcd_density=${base_rom_density}/g" ${prop}
    sed -i "s/persist.miui.density_v2=.*/persist.miui.density_v2=${base_rom_density}/g" ${prop}
done


vendorprop=$(find BASEROM/images/vendor/ -type f -name "build.prop")
odmprop=$(find BASEROM/images/odm/ -type f -name "build.prop" |awk 'NR==1')
if [ "$(cat $vendorprop |grep "sys.haptic" |awk 'NR==1')" != "" ];then
    Yellow "复制 haptic prop 到 odm"
    cat $vendorprop |grep "sys.haptic" >>${odmprop}
fi

# 处理 contexts 去重
Yellow "contexts 去重"
cat BASEROM/config/system_file_contexts |sort |uniq >system_file_contexts
cat BASEROM/config/product_file_contexts |sort |uniq >product_file_contexts
cat BASEROM/config/system_fs_config |sort |uniq >system_fs_config
cat BASEROM/config/product_fs_config |sort |uniq >product_fs_config
mv -f system_file_contexts BASEROM/config/system_file_contexts
mv -f product_file_contexts BASEROM/config/product_file_contexts
mv -f system_fs_config BASEROM/config/system_fs_config
mv -f product_fs_config BASEROM/config/product_fs_config
sed -i "1d" BASEROM/config/system_file_contexts
sed -i "1d" BASEROM/config/product_file_contexts
sed -i "1d" BASEROM/config/system_fs_config
sed -i "1d" BASEROM/config/product_fs_config


# 重新打包镜像
rm -rf BASEROM/images/system_bak*
rm -rf BASEROM/images/product_bak*
rm -rf BASEROM/images/system_ext_bak*
for pname in ${PORT_PARTITION};do
    rm -rf BASEROM/images/${pname}.img
done
echo "${packType}">fstype.txt
superSize=$(bash bin/getSuperSize.sh $deviceCode)
Green 开始打包镜像
for pname in ${SUPERLIST};do
    if [ -d "BASEROM/images/$pname" ];then
        thisSize=$(du -sb BASEROM/images/${pname} |tr -cd 0-9)
        case $pname in
            mi_ext) addSize=4194304 ;;
            odm) addSize=134217728 ;;
            system|vendor|system_ext) addSize=154217728 ;;
            product) addSize=204217728 ;;
            *) addSize=8554432 ;;
        esac
        if [ "$packType" = "ext4" ];then
            Yellow "$pname"为EXT4文件系统多分配大小$addSize
            for fstab in $(find BASEROM/images/${pname}/ -type f -name "fstab.*");do
                sed -i '/overlay/d' $fstab
                sed -i '/system * erofs/d' $fstab
                sed -i '/system_ext * erofs/d' $fstab
                sed -i '/vendor * erofs/d' $fstab
                sed -i '/product * erofs/d' $fstab
            done
            thisSize=$(echo "$thisSize + $addSize" |bc)
            Yellow 以[$packType]文件系统打包[${pname}.img]大小[$thisSize]
            make_ext4fs -J -T $(date +%s) -S BASEROM/config/${pname}_file_contexts -l $thisSize -C BASEROM/config/${pname}_fs_config -L ${pname} -a ${pname} BASEROM/images/${pname}.img BASEROM/images/${pname}
            if [ -f "BASEROM/images/${pname}.img" ];then
                Green "成功以大小 [$thisSize] 打包 [${pname}.img] [${packType}] 文件系统"
                rm -rf BASEROM/images/${pname}
            else
                Error "以 [${packType}] 文件系统打包 [${pname}] 分区失败"
            fi
        else
            Yellow 以[$packType]文件系统打包[${pname}.img]
            mkfs.erofs --mount-point ${pname} --fs-config-file BASEROM/config/${pname}_fs_config --file-contexts BASEROM/config/${pname}_file_contexts BASEROM/images/${pname}.img BASEROM/images/${pname}
            if [ -f "BASEROM/images/${pname}.img" ];then
                Green "成功以 [erofs] 文件系统打包 [${pname}.img]"
                rm -rf BASEROM/images/${pname}
            else
                Error "以 [${packType}] 文件系统打包 [${pname}] 分区失败"
            fi
        fi
        unset fsType
        unset thisSize
    fi
done
rm fstype.txt


read

# 打包 super.img
Yellow 开始打包Super.img

lpargs="-F --virtual-ab --output BASEROM/images/super.img --metadata-size 65536 --super-name super --metadata-slots 3 --device super:$superSize --group=qti_dynamic_partitions_a:$superSize --group=qti_dynamic_partitions_b:$superSize"

for pname in ${SUPERLIST};do
    if [ -f "BASEROM/images/${pname}.img" ];then
        subsize=$(du -sb BASEROM/images/${pname}.img |tr -cd 0-9)
        Green Super 子分区 [$pname] 大小 [$subsize]
        args="--partition ${pname}_a:none:${subsize}:qti_dynamic_partitions_a --image ${pname}_a=BASEROM/images/${pname}.img --partition ${pname}_b:none:0:qti_dynamic_partitions_b"
        lpargs="$lpargs $args"
        unset subsize
        unset args
    fi
done
lpmake $lpargs
if [ -f "BASEROM/images/super.img" ];then
    Green 成功打包 Super.img
else
    Error 无法打包 Super.img
fi
for pname in ${SUPERLIST};do
    rm -rf BASEROM/images/${pname}.img
done

Yellow "正在压缩 super.img"
zstd --rm BASEROM/images/super.img

# disable vbmeta
for img in $(find BASEROM/images/ -type f -name "vbmeta*.img");do
    vbmeta-disable-verification $img
done


mkdir -p PORT_${deviceCode}_${port_rom_version}/images
mkdir -p PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/
cp -rf bin/flash/update-binary PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/
cp -rf bin/flash/platform-tools-windows PORT_${deviceCode}_${port_rom_version}/META-INF/
cp -rf bin/flash/flash_update.bat PORT_${deviceCode}_${port_rom_version}/
cp -rf bin/flash/flash_and_format.bat PORT_${deviceCode}_${port_rom_version}/
mv -f BASEROM/images/super.img.zst PORT_${deviceCode}_${port_rom_version}/images/
mv -f BASEROM/images/*.img PORT_${deviceCode}_${port_rom_version}/images/
cp -rf bin/flash/zstd PORT_${deviceCode}_${port_rom_version}/META-INF/

# 生成刷机脚本
Yellow "正在生成刷机脚本"
for fwImg in $(ls PORT_${deviceCode}_${port_rom_version}/images/ |cut -d "." -f 1 |grep -vE "super|cust|preloader");do
    if [ "$(echo $fwImg |grep vbmeta)" != "" ];then
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_b images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_update.bat
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_a images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_update.bat
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_b images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_and_format.bat
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot --disable-verity --disable-verification flash "$fwImg"_a images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_and_format.bat
        sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_b\"" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
        sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_a\"" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    else
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_b images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_update.bat
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_a images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_update.bat
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_b images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_and_format.bat
        sed -i "/rem/a META-INF\\\platform-tools-windows\\\fastboot flash "$fwImg"_a images\/"$fwImg".img" PORT_${deviceCode}_${port_rom_version}/flash_and_format.bat
        sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_b\"" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
        sed -i "/#firmware/a package_extract_file \"images/"$fwImg".img\" \"/dev/block/bootdevice/by-name/"$fwImg"_a\"" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
    fi
done

sed -i "s/portversion/${port_rom_version}/g" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
sed -i "s/baseversion/${base_rom_version}/g" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
sed -i "s/andVersion/${port_android_version}/g" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary
sed -i "s/deviceCode/${base_rom_code}/g" PORT_${deviceCode}_${port_rom_version}/META-INF/com/google/android/update-binary

busybox unix2dosPORT_${deviceCode}_${port_rom_version}/flash_update.bat
busybox unix2dos PORT_${deviceCode}_${port_rom_version}/flash_and_format.bat

find PORT_${deviceCode}_${port_rom_version}/ |xargs touch

cd PORT_${deviceCode}_${port_rom_version}/
zip -r PORT_${deviceCode}_${port_rom_version}.zip ./*
mv PORT_${deviceCode}_${port_rom_version}.zip ../
cd ../
hash=$(md5sum PORT_${deviceCode}_${port_rom_version}.zip |head -c 10)
mv PORT_${deviceCode}_${port_rom_version}.zip PORT_${deviceCode}_${port_rom_version}_${hash}_${port_android_version}.zip
Green "移植完毕"
Green "输出包为 $(pwd)/PORT_${deviceCode}_${port_rom_version}_${hash}_${port_android_version}.zip"