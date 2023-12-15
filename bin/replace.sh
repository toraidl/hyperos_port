#!/bin/bash

# 创建目录
mkdir -p tosa

# 复制文件
cp -rf build/portrom/images/system/system/framework/services.jar tosa/

# 删除原文件
rm -rf build/portrom/images/system/system/framework/services.jar

# 进入目录
cd tosa

# 打印消息
echo "开始解码"

# 解码APK
apktool d services.jar -o services_jar_out

# 进入目录
cd services_jar_out/smali/com/android/server/

# 创建目录
mkdir -p weverse

# 复制文件
cp -rf /Users/tosasitill/Downloads/hyperos_port-main/bin/BypassSignCheck.smali ./weverse/

# 返回上级目录
cd ../../../../../../..

# 打印消息
echo "开始替换"

# 指定文件夹路径
search_text="Landroid/util/apk/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I"
replace_text="Lcom/android/server/weverse/BypassSignCheck;->getMinimumSignatureSchemeVersionForTargetSdk(I)I"

# 查找并替换
grep -rl "$search_text" "./tosa" | while read -r file; do
  sed -i "s/$search_text/$replace_text/g" "$file"
  echo "Replaced in: $file"
done

# 打印消息
echo "替换完成."

# 打印消息
echo "开始编译"

# 进入目录
cd tosa

# 编译APK
sudo apktool b services_jar_out -o modified_services.jar

# 打印消息
echo "编译完成"

# 打印消息
echo "开始替换"

# 删除原文件
rm -rf services.jar

# 重命名文件
mv modified_services.jar services.jar

# 返回上级目录
cd /Users/tosasitill/Downloads/hyperos_port-main

# 复制文件
sudo cp -rf ./tosa/services.jar build/portrom/images/system/system/framework/

# 返回上级目录
cd ..

# 删除目录
rm -rf tosa

# 打印消息
echo "操作完成"


