#!/usr/bin/env bash
# Copyright (C) 2020 Abubakar Yagoub (Blacksuan19)

BOT=$BOT_API_KEY

KERN_IMG=$PWD/out/arch/arm64/boot/Image.gz-dtb
ZIP_DIR=$HOME/Zipper
DEVICE="Vince"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT=$(git log --pretty=format:'"%h : %s"' -1)
CHAT_ID="-1001260562827"
CONFIG=vince-perf_defconfig
THREAD=-j$(nproc --all)
    
 [ -d $HOME/toolchains/aarch64 ] || git clone https://github.com/kdrag0n/aarch64-elf-gcc.git $HOME/toolchains/aarch64
 [ -d $HOME/toolchains/aarch32 ] || git clone https://github.com/kdrag0n/arm-eabi-gcc.git $HOME/toolchains/aarch32    


# upload to channel
function tg_pushzip() {
	JIP=$ZIP_DIR/$ZIP
	curl -F document=@"$JIP"  "https://api.telegram.org/bot$BOT/sendDocument" \
			-F chat_id=$CHAT_ID
}

# sed text message
function tg_sendinfo() {
	curl -s "https://api.telegram.org/bot$BOT/sendMessage" \
		-d "parse_mode=html" \
		-d text="${1}" \
		-d chat_id="-1001260562827" \
		-d "disable_web_page_preview=true"
}


# finished with error
function tg_error() {
	tg_sendinfo "Reep build Failed, Check log for more Info"
	exit 1
}

# send build details
function tg_sendbuildinfo() {
        tg_sendinfo "<b>New Kernel Build for $DEVICE</b>
	    Started on: <b>$KBUILD_BUILD_HOST</b>
	    Branch: <b>$BRANCH</b>
        Commit: <b>$COMMIT</b>
	    Date: <b>$(date)</b>"
}

# build the kernel
function build_kern() {
    DATE=`date`
    BUILD_START=$(date +"%s")

    # cleaup first
    rm -rf out
    make clean && make mrproper

    # building
    make O=out $CONFIG $THREAD
    make O=out $THREAD \
                    CROSS_COMPILE=$HOME/toolchains/aarch64/bin/aarch64-elf- \
                    CROSS_COMPILE_ARM32=$HOME/toolchains/aarch32/bin/arm-eabi- 
    
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
    
    if ! [ -a $KERN_IMG ]; then
    	tg_error
    	exit 1
    fi
}

# make flashable zip
function make_flashable() {
    cd $ZIP_DIR
    make clean &>/dev/null
    cp $KERN_IMG $ZIP_DIR/zImage
    make stable &>/dev/null
    echo "Flashable zip generated under $ZIP_DIR."
    ZIP=$(ls | grep *.zip | grep -v *.sha1)
    tg_pushzip
    cd -
}

# Export
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="StarLight5234"
export KBUILD_BUILD_HOST="Cosmic Horizon"
export LINUX_VERSION=$(awk '/SUBLEVEL/ {print $3}' Makefile \
    | head -1 | sed 's/[^0-9]*//g')

# Clone AnyKernel3
[ -d $HOME/Zipper ] || git clone https://github.com/starlight5234/Zipper $HOME/Zipper

# send shit to telegram
tg_sendbuildinfo

# build kramel
build_kern

# make zip
make_flashable
