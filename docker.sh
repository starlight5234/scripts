# Please mention stuff here
DEVICE="$DEV" # device codename in all small plox
CONFIG="$CONF" # Your kernels defconfig ( not needed to mention for vince and lavender )
CHANNEL_ID="$ID" # Your channel where you want kernel to be posted
TELEGRAM_TOKEN="$BOT_API_KEY" # API Token of YOUR bot ( make sure bot is admin ofc )
TC_PATH="$HOME/toolchains" # Name your toolchain folder { I don't mess with this }
ZIP_DIR="$HOME/Zipper"
USE_GCC="no"
IS_MIUI="no"

# Device Check
if [ "$DEVICE" == "vince" ]; then
	export CONFIG=vince-perf_defconfig
fi

# Telegram Start

# upload build log to channel on failing
tg_erlog()
{
	ERLOG=$HOME/build/build${BUILD}.txt
	curl -F document=@"$ERLOG"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id=$CHANNEL_ID
}

# upload zip to channel
tg_pushzip() 
{
	JIP=$ZIP_DIR/$ZIP
	curl -F document=@"$JIP"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
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
if [ "$USE_GCC" == "yes" ]; then
	[ -d ${TC_PATH}/gcc-arm64 ] || git clone --depth=1 https://github.com/Unitrix-Kernel/aarch64-linux-android-4.9.git ${TC_PATH}/gcc-arm64

	[ -d ${TC_PATH}/gcc-arm ] || git clone --depth=1 https://github.com/Unitrix-Kernel/arm-linux-androideabi-4.9.git ${TC_PATH}/gcc-arm
	export CROSS_COMPILE="${TC_PATH}/gcc-arm64/bin/aarch64-linux-android-"
	export CROSS_COMPILE_ARM32="${TC_PATH}/gcc-arm/bin/arm-linux-androideabi-"
	export PATH="${TC_PATH}/gcc-arm64/bin:${TC_PATH}/gcc-arm/bin:{$PATH}"
	export STRIP="${TC_PATH}/gcc-arm64/bin/aarch64-linux-android-strip"	
else 
	[ -d ${TC_PATH}/clang ] || git clone --depth=1 https://github.com/Unitrix-Kernel/unitrix-clang.git ${TC_PATH}/clang
	export PATH="${TC_PATH}/clang/bin:$PATH"
	export STRIP="${TC_PATH}/clang/aarch64-linux-gnu/bin/strip"
fi
}

function clone_zipper() {
if [ "$DEVICE" == "vince" ]; then
	git clone https://github.com/Unitrix-Kernel/AnyKernel3.git -b vince $ZIP_DIR
else 
	WOT=$(echo "Plox Mention your AnyKernel source")
	tg_sandinfo "${WOT}"
fi
}

build_clang () {
	make -j$(nproc --all) O=out \
                          ARCH=arm64 \
			  AR=llvm-ar \
			  NM=llvm-nm \
			  OBJCOPY=llvm-objcopy \
			  OBJDUMP=llvm-objdump \
			  STRIP=llvm-strip \
                          CC=clang \
                          CROSS_COMPILE=aarch64-linux-gnu- \
			  CROSS_COMPILE_ARM32=arm-linux-gnueabi- |& tee -a $HOME/build/build${BUILD}.txt
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
	if [ "$DEVICE" == "vince" ]; then
		git checkout vince &>/dev/null
	fi
	make clean &>/dev/null
	cp $KERN_IMG $ZIP_DIR/zImage
	if [ "$BRANCH" == "stable" ] || [ "$BRANCH" == "stable-perf" ]; then
	    make stable &>/dev/null
	elif [ "$BRANCH" == "beta" ]; then
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
[ -d "$ZIP_DIR" ] || clone_zipper

# Main/Common environment
COMMIT=$(git log --pretty=format:'"%h : %s"' -1)
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=$(pwd)
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
CONFIG_PATH=$KERNEL_DIR/arch/arm64/configs/$CONFIG
VENDOR_MODULEDIR="$ZIP_DIR/modules/vendor/lib/modules"

# Setup TC & build kernel when?

export KERN_VER=$(echo "$(make kernelversion)")
make mrproper && rm -rf out

tg_sandinfo "$(echo "Kernel for :- <b>$DEVICE</b> 
Version    :- <b>$KERN_VER</b> 
on Branch  :- <b>$BRANCH</b>
Commit	   :- <b>$COMMIT</b>")"

# Make defconfig & kernul 
DATE=`date`
BUILD_START=$(date +"%s")
make O=out ARCH=arm64 "$CONFIG"

# Compiler specific kernel make command
if [ "$USE_GCC" == "yes" ]; then
	build_gcc
else
	build_clang
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
# Check if Kernel Image exists
if ! [ -a "$KERN_IMG" ]; then
	tg_sandinfo "$(echo "Build ran into errors after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds, plox check logs")"
	tg_erlog
	exit 1
else
	tg_sandinfo "$(echo "Build Finished after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds
	Sending the image to make flashble")"

	# Zip kernel
	cd $ZIP_DIR
	if [ "$IS_MIUI" == "yes" ]; then
		wifi_modules && make_flashable
	else
		make_flashable
	fi
fi
