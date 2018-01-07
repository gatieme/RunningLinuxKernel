show_usage( )
{
	common=$0
	echo "Usage"
	echo -e "\t$common todo arch build_root_dir"
}


bakcup_kernel_image( )
{
	echo ""

}


qemu_run_kernel( )
{
	common=$0
	if [ ! -f "$IMAGE_FILE" ];then
		echo "image $IMAGE_FILE not found"
		echo "you should build your kernel first"
		echo "run the next :"
		echo "\t$common build $ARCH $BUILD_ROOT_DIR"
		exit -1
	fi

	echo "====================="
	echo "qemu $QEMU_SYSTEM_BIN"
	echo "image $IMAGE_FILE"
	echo "====================="

	if [ $ARCH = "x86_64" ]; then
		$QEMU_SYSTEM_BIN									\
			-smp 4 -m 2048M							\
			-kernel $IMAGE_FILE						\
			-append "rdinit=/linuxrc console=ttyS0" -nographic
	elif [ $ARCH = "arm64" ]; then
		$QEMU_SYSTEM_BIN									\
			-machine virt -cpu cortex-a57 -machine type=virt 				\
			-smp 4 -m 2048M									\
			-kernel $IMAGE_FILE						\
			-append "rdinit=/linuxrc console=ttyAMA0 loglovel=8" 		\
			-nographic
	elif [ $ARCH = "arm" ]; then
		$QEMU_SYSTEM_BIN									\
			-M vexpress-a9 -smp 2 -m 1024M							\
			-kernel $IMAGE_FILE						\
			-append "rdinit=/linuxrc console=ttyAMA0" -nographic		\
			-dtb ${DTB_FILE}
	fi
}



qemu_debug_kernel( )
{
	echo "====================="
	echo "qemu $QEMU_SYSTEM_BIN"
	echo "image $IMAGE_FILE"
	echo "====================="

	TMUX_BIN=$(which tmux)
	TMUX_SESSION=kerneldebug

	if [ -z $TMUX_BIN ]; then
		echo "You need to install tmux."
	fi

	$TMUX_BIN has -t $TMUX_SESSION

	if [ $ARCH = "arm64" ];then
		$TMUX_BIN new -d -n vim -s $TMUX_SESSION \"$QEMU_SYSTEM_BIN -machine virt -cpu cortex-a57 -machine type=virt -smp 4 -m 2048M -kernel ${IMAGE_FILE} -append \"rdinit=/linuxrc console=ttyAMA0 loglovel=8\" -nographic
		$TMUX_BIN splitw -h -p 50 -t $TMUX_SESSION \"aarch64-linux-gnu-gdb\" $VMLINUX_FILE
	fi

	#$TMUX_BIN -v -p 20 -t $session "zsh" #水瓶分割
	#$TMUX_BIN -h -p 50 -t %$TMUX_SESSION "aarch64-linux-gnu-gdb"  # 垂直划分

	$TMUX_BIN slectw -t $TMUX_SESSION:1
	$TMUX_BIN att -t $TMUX_SESSION

	#exit 0
}


running_linux_kernel( )
{
	local TO_DO=$1
	local ARCH=$2
	local BUILD_ROOT_DIR=$3

	if [ $TO_DO = "run" ]; then
		qemu_run_kernel
	elif [ $TO_DO = "debug" ]; then
		debug_run_kernel
	fi
}

if [ $# != 3 ]; then
	show_usage
	exit 0
fi

if [ -z "$KERNEL_NAME" ];then
	KERNEL_NAME=linux
fi

ROOT_DIR=..
TO_DO=$1
ARCH=$2
BUILD_ROOT_DIR=$3


BUILD_OUTPUT_DIR=$BUILD_ROOT_DIR/build/$ARCH
BUILD_KERNEL_DIR=$BUILD_ROOT_DIR/build/$KERNEL_NAME
BUILD_PATCH_DIR=#BUILD_ROOT_DIR/patch

QEMU_SYSTEM_DIR=/opt/software/qemu/2.11.0/bin

if [ ! -d "$BUILD_ROOT_DIR" ];then
	echo "ERROR $BUILD_ROOT_DIR Not found"
	echo "It's the place where your kernel_src, build, patch stay"
	echo "you should mkdir $KERNEL_NAME, build in it"
	echo
fi

if [ ! -d "$BUILD_OUTPUT_DIR" ];then
	echo "WARNING $BUILD_KERNEL_DIR Not found"
	echo "It's the place where build your kernel and your image stay"
	echo "We will create/mkdir it"
fi

if [ $ARCH = "x86_64" ];then
	IMAGE_FILE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/bzImage
	QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-x86_64
	#CROSS_COMPILE=aarch64-linux-gnu-
elif [ $ARCH = "arm64" ];then
	IMAGE_FILE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/zImage
	QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-aarch64
	CROSS_COMPILE=aarch64-linux-gnu-
	#DTB_FILE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/dts/vexpress-v2p-ca9.dtb
elif [ $ARCH = "arm" ];then
	IMAGE_FILE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/bzImage
	QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-arm
	CROSS_COMPILE=arm-linux-gnueabi-
	DTB_FILE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/dts/vexpress-v2p-ca9.dtb
else
	echo "Uknown $ARCH"
	exit -1
fi


VMLINUX_FILE=$BUILD_OUTPUT_DIR/vmlinux
CONFIG_FILE=$BUILD_OUTPUT_DIR/.config

BAKCUP_DIR=$ROOT_DIR/backup/$ARCH

running_linux_kernel $TO_DO $ARCH $BUILD_ROOT_DIR
