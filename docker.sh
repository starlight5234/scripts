# Please mention stuff here ( for not vince just change DEVICE )
DEVICE="vince" # device codename in all small plox
CONFIG="" # Your kernels defconfig also mention your DEVICE
CHANNEL_ID="-405830689" # Your channel where you want kernel to be posted
TELEGRAM_TOKEN="$BOT_API_KEY" # API Token of YOUR bot ( make sure bot is admin ofc )
TC_PATH="$HOME/toolchains" # Name your toolchain folder { I don't mess with this }
ZIP_DIR="$HOME/Zipper"
CCACHE="no" # yes or no (clang compiler only)
USE_CLANG="yes"

# Wanna setup ccache?
if [ $CCACHE == "no" ]; then
	export CLANG="${TC_PATH}/clang/bin/clang"
else
	export CLANG="ccache ${TC_PATH}/clang/bin/clang"
fi

# Device Check
if [ $DEVICE == "vince" ]; then
	export CONFIG=vince-perf_defconfig
fi

# Telegram Start

# upload to channel
tg_pushzip() 
{
	JIP=$ZIP_DIR/$ZIP
	curl -F document=@"$JIP"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id=$CHANNEL_ID
	SHA=$ZIP_DIR/$ZIP.sha1
	curl -F document=@"$MD5"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id=$CHANNEL_ID
	ERLOG=$HOME/build/build${BUILD}.txt
	curl -F document=@"$ERLOG"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id=$CHANNEL_ID
}

# Sand Updates
function tg_sandinfo() {
	curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
		-d "parse_mode=html" \
		-d text="${1}" \
		-d chat_id="${CHANNEL_ID}" \
		-d "disable_web_page_preview=true"
}

# Telegram End

# Log output Stuff {logic creds: @madeofgreat}
BTXT="$HOME/build/buildno.txt" #BTXT is Build number TeXT
if ! [ -a "$BTXT" ]; then
	tg_sandinfo "$(echo "Why no build tracker???")"
	mkdir $HOME/build
	touch $HOME/build/buildno.txt
	echo 1 > $BTXT
fi

BUILD=$(cat $BTXT)
BUILD=$(($BUILD + 1))
echo ${BUILD} > $BTXT
# End of Log output stuff

# START OF ALL THE CRAZY FUNCTIONS ===========

# Toolchain & Zipper Cloner
function clone_tc() {
[ -d ${TC_PATH} ] || mkdir ${TC_PATH}
if [ $USE_CLANG == "yes" ]; then
	[ -d ${TC_PATH}/clang ] || git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6443078 ${TC_PATH}/clang && rm -rf ${TC_PATH}/clang/.git
        export CLANG="${TC_PATH}/clang/bin/clang"
fi

[ -d ${TC_PATH}/gcc-arm64 ] || git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r50 ${TC_PATH}/gcc-arm64 && rm -rf ${TC_PATH}/gcc-arm64/.git

[ -d ${TC_PATH}/gcc-arm ] || git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r50 ${TC_PATH}/gcc-arm && rm -rf ${TC_PATH}/gcc-arm/.git

}

function clone_zipper() {
if [ $DEVICE == "vince" ]; then
	git clone https://github.com/starlight5234/Zipper -b master $ZIP_DIR #VINCE 
else
	git clone https://github.com/starlight5234/Zipper -b test $ZIP_DIR
fi
}

build_clang () {
	make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CC="${CLANG}" \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          LLVM="llvm-" |& tee -a $HOME/build/build${BUILD}.txt
}

build_gcc () {
	make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CROSS_COMPILE=${CROSS_COMPILE} \
                          CROSS_COMPILE_ARM32=${CROSS_COMPILE_ARM32} |& tee -a $HOME/build/build${BUILD}.txt
}

# Functions
wifi_modules () {
    # credit @adekmaulana
    for MODULES in $(find "$KERNEL_DIR/out" -name '*.ko'); do
        "${STRIP}" --strip-unneeded --strip-debug "${MODULES}"
        "$KERNEL_DIR/scripts/sign-file" sha512 \
                "$KERNEL_DIR/out/signing_key.priv" \
                "$KERNEL_DIR/out/signing_key.x509" \
                "${MODULES}"
        case ${MODULES} in
                */wlan.ko)
            cp "${MODULES}" "${VENDOR_MODULEDIR}/pronto_wlan.ko"
            ;;
        esac
    done
    echo -e "(i) Done moving wifi modules"
}

# make flashable zip
function make_flashable() {
	cd $ZIP_DIR
	if [ $DEVICE == "vince" ]; then
		git checkout master &>/dev/null
	else
		git checkout test &>/dev/null
	fi
	make clean &>/dev/null
	cp $KERN_IMG $ZIP_DIR/zImage
    	tg_sandinfo "$(echo "Zipping the KERNUL. 3. 2. 1. Go BRRRRR lmao")"
	if [ $BRANCH == "stable" ] || [ $BRANCH == "stable-perf" ]; then
	    make stable &>/dev/null
	elif [ $BRANCH == "beta" ]; then
	    make beta &>/dev/null
	else
	    make test &>/dev/null
	fi
	ZIP=$(ls | grep *.zip | grep -v *.sha1)
	tg_pushzip
}

# END OF ALL THEM CRAZY FUNCTION =================

# Clone some basic stuff
clone_tc
[ -d $ZIP_DIR ] || clone_zipper && tg_sandinfo "$(echo "Cloned Toolchain & Zipper. Entering Work Directory")"

# Main/Common environment
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
CONFIG_PATH=$KERNEL_DIR/arch/arm64/configs/$CONFIG
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"
STRIP="${TC_PATH}/gcc-arm64/bin/aarch64-linux-android-strip"

# Setup TC & build kernel when?
export CROSS_COMPILE="${TC_PATH}/gcc-arm64/bin/aarch64-linux-android-"
export CROSS_COMPILE_ARM32="${TC_PATH}/gcc-arm/bin/arm-linux-androideabi-"
export KERN_VER=$(echo "$(make kernelversion)")
make clean && make mrproper
tg_sandinfo "$(echo "Env Setup completed. Making kernel for $DEVICE version $KERN_VER SoonTM.</br>on Branch: $BRANCH")"

# Make defconfig & kernul 
DATE=`date`
BUILD_START=$(date +"%s")
make O=out ARCH=arm64 "$CONFIG"

# Device specific kernel make command
if [ $USE_CLANG == "no" ]; then
	export PATH="${TC_PATH}/gcc-arm64/bin:${TC_PATH}/gcc-arm/bin:{$PATH}"
	build_gcc
else
	export PATH="${TC_PATH}/clang/bin:${TC_PATH}/gcc-arm64/bin:${TC_PATH}/gcc-arm/bin:{$PATH}"
	build_clang
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
# Check if Kernel Image exists
if ! [ -a "$KERN_IMG" ]; then
	tg_sandinfo "$(echo "Build ran into errors after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds, plox check logs")"
	exit 1
else
	tg_sandinfo "$(echo "Build Finished after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds")"

	# Zipper check
	cd $ZIP_DIR
	if [ $DEVICE != "vince" ]; then
		wifi_modules && make_flashable
	else
		make_flashable
	fi
fi
