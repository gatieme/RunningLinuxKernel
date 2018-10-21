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
	if [ ! -f "$KERNEL_IMAGE" ];then
		echo "image $KERNEL_IMAGE not found"
		echo "you should build your kernel first"
		echo "run the next :"
		echo "\t$common build $ARCH $BUILD_ROOT_DIR"
		exit 1
	fi

	echo "====================="
	echo "qemu $QEMU_SYSTEM_BIN"
	echo "image $KERNEL_IMAGE"
	echo "initrdfs $INITRDFS"
	echo "====================="

	case $ARCH in
		x86_64)
		qemu-system-x86_64 -kernel $KERNEL_IMAGE \
				   -append "root=/dev/ram rdinit=/linuxrc console=ttyS0" -nographic \
				   -initrd $INITRDFS	\
				   --virtfs local,id=kmod_dev,path=$VIRFS,security_model=none,mount_tag=kmod_mount \
				   $DBG ;;
		x86)
		qemu-system-i386 -kernel $KERNEL_IMAGE \
				 -append "/root=/dev/ram rdinit=/linuxrc console=ttyS0" -nographic \
				 -initrd $INITRDFS \
				 --virtfs local,id=kmod_dev,path=$VIRFS,security_model=none,mount_tag=kmod_mount \
				 $DBG ;;
		arm)
		qemu-system-arm -M vexpress-a9 -smp 4 -m 1024M -kernel $KERNEL_IMAGE \
				-dtb $DTB_FILE -nographic \
				-append "root=/dev/ram rdinit=/linuxrc console=ttyAMA0 loglevel=8" \
				-initrd $INITRDFS \
				--fsdev local,id=kmod_dev,path=$VIRFS,security_model=none -device virtio-9p-device,fsdev=kmod_dev,mount_tag=kmod_mount \
				$DBG ;;
		arm64)
		qemu-system-aarch64 -machine virt -cpu cortex-a57 -machine type=virt \
				    -m 1024 -smp 2 -kernel $KERNEL_IMAGE \
				    -append "root=/dev/ram rdinit=/linuxrc console=ttyAMA0" -nographic \
				    -initrd $INITRDFS \
				    --fsdev local,id=kmod_dev,path=$VIRFS,security_model=none -device virtio-9p-device,fsdev=kmod_dev,mount_tag=kmod_mount \
				    $DBG ;;
				    esac
}



qemu_debug_kernel( )
{
	echo "====================="
	echo "qemu $QEMU_SYSTEM_BIN"
	echo "image $KERNEL_IMAGE"
	echo "====================="

	TMUX_BIN=$(which tmux)
	if [ -z $TMUX_BIN ]; then
		echo "You need to install tmux."
		exit 1
	fi

	TMUX_SESSION=kdebug
	$TMUX_BIN has -t $TMUX_SESSION
	if [ $? = 0 ]; then
		echo "$TMUX_SESSION have been started."
		exit 1
	fi

	if [ $ARCH = "x86_64" ];then
		$TMUX_BIN new -d -n vim -s $TMUX_SESSION "echo $QEMU_SYSTEM_BIN -smp 4 -m 2048M -kernel $KERNEL_IMAGE -append \"rdinit=/linuxrc console=ttyS0\" -nographic -S -s"
		$TMUX_BIN splitw -h -p 50 -t $TMUX_SESSION "gdb $VMLINUX_FILE"
	elif [ $ARCH = "arm64" ];then
		$TMUX_BIN new -d -n arm64_debug -s $TMUX_SESSION "$QEMU_SYSTEM_BIN -machine virt -cpu cortex-a57 -machine type=virt -smp 4 -m 2048M -kernel $KERNEL_IMAGE -append \"rdinit=/linuxrc console=ttyAMA0 loglovel=8\" -nographic -S -s"
		$TMUX_BIN splitw -h -p 50 -t $TMUX_SESSION "aarch64-linux-gnu-gdb $VMLINUX_FILE"
	fi

	#$TMUX_BIN -v -p 20 -t $session "zsh" #水瓶分割
	#$TMUX_BIN -h -p 50 -t %$TMUX_SESSION "aarch64-linux-gnu-gdb"  # 垂直划分

	$TMUX_BIN selectw -t $TMUX_SESSION:1
	$TMUX_BIN att -t $TMUX_SESSION

	exit 0
}


running_linux_kernel( )
{
	local TO_DO=$1
	local ARCH=$2
	local BUILD_ROOT_DIR=$3

	if [ $TO_DO = "run" ]; then
		qemu_run_kernel
	elif [ $TO_DO = "debug" ]; then
		qemu_debug_kernel
	fi
}

if [ $# != 3 ]; then
	show_usage
	exit 0
fi

if [ -z "$KERNEL_NAME" ];then
	KERNEL_NAME=src
fi

ROOT_DIR=..
TO_DO=$1
ARCH=$2
BUILD_ROOT_DIR=$3


BUILD_OUTPUT_DIR=$BUILD_ROOT_DIR/build/$ARCH
BUILD_KERNEL_DIR=$BUILD_ROOT_DIR/$KERNEL_NAME
BUILD_PATCH_DIR=#BUILD_ROOT_DIR/patch

QEMU_SYSTEM_DIR=/opt/software/toolchain/qemu/bin

INITRDFS=$ROOT_DIR/filesystem/initrdfs/$ARCH/rootfs.cpio.gz
VIRFS=$ROOT_DIR/filesystem/9p_virfs


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

case $ARCH in
	x86_64)
		KERNEL_IMAGE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/bzImage
		QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-x86_64
	;;
	arm64)
		KERNEL_IMAGE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/Image
		QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-aarch64
		CROSS_COMPILE=aarch64-linux-gnu-
	;;
	arm)
		KERNEL_IMAGE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/zImage
		QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-arm
		CROSS_COMPILE=arm-linux-gnueabi-
		DTB_FILE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/dts/vexpress-v2p-ca9.dtb
	;;
	x86)
		KERNEL_IMAGE=$BUILD_OUTPUT_DIR/arch/$ARCH/boot/bzImage
		QEMU_SYSTEM_BIN=$QEMU_SYSTEM_DIR/qemu-system-i386
	;;
	*)
	echo "Uknown $ARCH"
	exit 1
esac


VMLINUX_FILE=$BUILD_OUTPUT_DIR/vmlinux
CONFIG_FILE=$BUILD_OUTPUT_DIR/.config

BAKCUP_DIR=$ROOT_DIR/backup/$ARCH

running_linux_kernel $TO_DO $ARCH $BUILD_ROOT_DIR
