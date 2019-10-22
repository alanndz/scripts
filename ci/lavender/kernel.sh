#!/usr/bin/env bash
#
# Copyright (C) 2019 @alanndz (Telegram and Github)
# SPDX-License-Identifier: GPL-3.0-or-later
#
# New Automatic Build for lavender
#
#
# Default Settings
export RELEASE_STATUS
export KERNEL_VERSION
export TYPE_KERNEL
export CODENAME
export TARGET_ROM
export USECLANG
 
KERNEL_NAME="aLn"
CONFIG_FILE="lavender_defconfig"
DEVICES="lavender"
TARGET_ARCH=arm64
DEVELOPER="alanndz"
HOST="n00b_lavender-Dev"

export TZ=":Asia/Makassar"

# COMPILER
# 0 = STOCK 4.9
# 1 = GNU 8.3
# USECLANG
# 0
# 1 = CLANG 10 from NusantaraDev
# 2 = CLANG 10 from Haseo

JOBS="-j$(($(nproc --all) + 4))"
 
if [ ! $RELEASE_STATUS ]; then
   RELEASE_STATUS=0
fi
if [ ! $KERNEL_VERSION ]; then
   KERNEL_VERSION="1.00"
fi
if [ ! $TYPE_KERNEL ]; then
   TYPE_KERNEL="HMP"
fi
if [ ! $CODENAME ]; then
   CODENAME="Testing"
fi
if [ ! $TARGET_ROM ]; then
   TARGET_ROM="aosp"
fi
if [ ! $USECLANG ]; then
   USECLANG=0
fi

# Location of Toolchain
KERNELDIR=$PWD
TOOLDIR=$KERNELDIR/.ToolBuild
ZIP_DIR="${TOOLDIR}/AnyKernel3"
OUTDIR="${KERNELDIR}/.Output"
IMAGE="${OUTDIR}/arch/arm64/boot/Image.gz-dtb"
 
# Download tool
git clone https://github.com/aln-project/AnyKernel3 -b "${DEVICES}-${TARGET_ROM}" ${ZIP_DIR}
 
if [ $USECLANG -eq 1 ]; then 
    git clone https://github.com/NusantaraDevs/clang.git --depth=1 -b dev/10.0 "${TOOLDIR}/clang10"
    TOOL_VERSION=$("${TOOLDIR}/clang10/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
elif [ $USECLANG -eq 2 ]; then 
    git clone https://github.com/Haseo97/Clang-10.0.0 --depth=1 "${TOOLDIR}/clang10"
    TOOL_VERSION=$("${TOOLDIR}/clang10/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
fi
 
# Telegram Function
BOT_API_KEY=$(openssl enc -base64 -d <<< Nzk5MDU4OTY3OkFBRlpjVEM5SU9lVEt4YkJucHVtWG02VHlUOTFzMzU5Y3VVCg==)
CHAT_ID=$(openssl enc -base64 -d <<< LTEwMDEyMzAyMDQ5MjMK)
export BUILD_FAIL="CAADBQAD5xsAAsZRxhW0VwABTkXZ3wcC"
export BUILD_SUCCESS="CAADBQADeQAD9kkAARtA3tu3hLOXJwI"
 
function sendInfo() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d chat_id=$CHAT_ID -d "parse_mode=HTML" -d text="$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )" 
&>/dev/null
}
 
function sendZip() {
	curl -F chat_id="$CHAT_ID" -F document=@"$ZIP_DIR/$ZIP_NAME" https://api.telegram.org/bot$BOT_API_KEY/sendDocument
}
 
function sendStick() {
	curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="${1}" -d chat_id=$CHAT_ID &>/dev/null
}
 
function sendLog() {
	curl -F chat_id="671339354" -F document=@"$BUILDLOG" https://api.telegram.org/bot$BOT_API_KEY/sendDocument &>/dev/null
}
 
#####

BUILDLOG="${OUTDIR}/build-${CODENAME}-${DEVICES}-$(date "+%H%M-%d%m%Y").log"

if [ $RELEASE_STATUS -eq 1 ]; then
	if [ "${CODENAME}" ]; then
		KVERSION="${CODENAME}-${KERNEL_VERSION}"
	else
		KVERSION="${CODENAME}"
	fi
	ZIP_NAME="${KERNEL_NAME}-${KVERSION}-${DEVICES}-$(date "+%H%M-%d%m%Y").zip"
elif [ $RELEASE_STATUS -eq 0 ]; then
	KVERSION="${CODENAME}-$(git log --pretty=format:'%h' -1)-$(date "+%H%M")"
	ZIP_NAME="${KERNEL_NAME}-${CODENAME}-${DEVICES}-$(git log --pretty=format:'%h' -1)-$(date "+%H%M").zip"
fi
 
if [ ! -d "${BUILDLOG}" ]; then
 	rm -rf "${BUILDLOG}"
fi
 
####
 
function make_zip () {
	cd ${ZIP_DIR}/
	make clean &>/dev/null
	if [ ! -f ${IMAGE} ]; then
        	echo -e "Build failed :P";
        	sendInfo "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")";
	        sendInfo "$(echo -e "Kernel compilation failed")";
			sendStick "${BUILD_FAIL}"
			sendLog
        	exit 1;
	fi
	echo "**** Copying zImage ****"
	cp ${IMAGE} ${ZIP_DIR}/zImage
	make ZIP="${ZIP_NAME}" normal &>/dev/null
}
 
function clean_outdir() {
    make ARCH=$TARGET_ARCH O=${OUTDIR} clean
    make mrproper
    rm -rf ${OUTDIR}/*
}
 
MODULEDIR="${ZIP_DIR}/modules/vendor/lib/modules/"
PRONTO="${MODULEDIR}pronto/pronto_wlan.ko"
STRIP="${TOOLCHAIN64}/bin/$(echo "$(find "${TOOLCHAIN64}/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"
 
function strip_module () {
	# thanks to @adekmaulana
	for MOD in $(find "${OUTDIR}" -name '*.ko') ; do
		"${STRIP}" --strip-unneeded --strip-debug "${MOD}" #&>/dev/null
		"${KERNELDIR}/"/scripts/sign-file sha512 \
				"${OUTDIR}/signing_key.priv" \
				"${OUTDIR}/signing_key.x509" \
				"${MOD}"
		find "${OUTDIR}" -name '*.ko' -exec cp {} "${MODULEDIR}" \;
		case ${MOD} in
			*/wlan.ko)
				cp -ar "${MOD}" "${PRONTO}"
		esac
	done
	echo -e "\n(i) Done moving modules"
}
 
BUILD_START=$(date +"%s")
DATE=`date`
 
sendInfo "<b>---- aLn New Kernel ----</b>" \
    "<b>Device:</b> lavender or Redmi Note 7" \
    "<b>Name:</b> <code>aLn-${KVERSION}</code>" \
    "<b>Kernel Version:</b> <code>$(make kernelversion)</code>" \
    "<b>Type:</b> <code>${TYPE_KERNEL}</code>" \
    "<b>Commit:</b> <code>$(git log --pretty=format:'%h : %s' -1)</code>" \
    "<b>Started on:</b> <code>$(hostname)</code>" \
    "<b>Compiler:</b> <code>${TOOL_VERSION}</code>" \
    "<b>Started at</b> <code>$DATE</code>"
 
clean_outdir

export LD_LIBRARY_PATH="${TOOLDIR}/clang10/bin/../lib:$PATH"

function compile_clang10() {
    make ARCH=arm64 O="${OUTDIR}" "${CONFIG_FILE}"
    PATH="${TOOLDIR}/clang10/bin:${PATH}" \
    make -j$(nproc --all) O="${OUTDIR}" \
                          ARCH=arm64 \
                          CC=clang \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-gnu- \
                          CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                          LOCALVERSION="-${KVERSION}" \
                          KBUILD_BUILD_USER="${DEVELOPER}" \
                          KBUILD_BUILD_HOST="${HOST}"
#                          KBUILD_COMPILER_STRING="${TOOL_VERSION}"
}

compile_clang10 2>&1 | tee "${BUILDLOG}"

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
 
if [ "${TARGET_ROM}" == "miui" ]; then
    cd ${ZIP_DIR}/
    make clean &>/dev/null
    strip_module
fi
 
if [ -d ${KERNELDIR}/patch ]; then
    cp -rf ${KERNELDIR}/patch ${ZIP_DIR}/
fi
 
make_zip
# sendInfo "$(echo -e "NOTE!!! INSTALL on ROM ${CODENAME} ONLY!!!")" 
sendZip
sendLog
sendInfo "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
sendStick "${BUILD_SUCCESS}"
 

