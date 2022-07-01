show_usage( )
{
	common=$0
	echo "Usage"
	echo -e "\t$common todo arch build_root_dir"
}


get_fullpath()
{
	#判断是否有参数,比如当前路径为/home/user1/workspace   参数为 ./../dir/hello.c
	if [ -z $1 ]
        then
	        return 1
	fi
        relative_path=$1

	#取前面一部分目录,比如  ./../../ ,  ../../ 等, 在这里调用cd命令来获取这部分路径的绝对路径,因为按这样写的,在当前路径的上级目录肯定是存在的.

	#tmp_path1为 ./..

	#tmp_fullpath1 /home/user1
	tmp_path1=$(echo $relative_path | sed -e "s=/[^\.]*$==")
	tmp_fullpath1=$(cd $tmp_path1 ;  pwd)

	#获取后面一部分路径
	#tmp_path2为dir/hello.c

	tmp_path2=$(echo $relative_path | sed -e "s=\.[\./]*[/|$]==")
	#echo $tmp_fullpath1
	#echo $tmp_path1
	#echo $tmp_path2
	#拼凑路径返回
	echo ${tmp_fullpath1}/${tmp_path2}
	return 0
}

bakcup_kernel_image( )
{
	echo ""

}

qemu_build_kernel( )
{
	JOBS=`grep -c ^processor /proc/cpuinfo 2>/dev/null`

	cd $BUILD_KERNEL_DIR
	make mrproper
	make defconfig O=$BUILD_OUTPUT_DIR
	cd $BUILD_OUTPUT_DIR
	make -j20 #$(JOBS)
}

qemu_run_kernel( )
{
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
	echo "virtiofs $VIRFS"
	echo "====================="

	case $ARCH in
		x86_64)
			qemu-system-x86_64 -machine pc,usb=on -enable-kvm												\
				-m 4G -smp cores=2,threads=2,sockets=4												\
				-object memory-backend-ram,id=mem0,size=1G												\
				-object memory-backend-ram,id=mem1,size=1G												\
				-object memory-backend-ram,id=mem2,size=1G												\
				-object memory-backend-ram,id=mem3,size=1G												\
				-numa node,memdev=mem0,cpus=0-3,nodeid=0 -numa node,memdev=mem1,cpus=4-7,nodeid=1							\
				-numa node,memdev=mem2,cpus=8-11,nodeid=2 -numa node,memdev=mem3,cpus=12-15,nodeid=3							\
				-numa dist,src=0,dst=1,val=12 -numa dist,src=0,dst=2,val=20										\
				-numa dist,src=0,dst=3,val=22 -numa dist,src=1,dst=2,val=22										\
				-numa dist,src=1,dst=3,val=24 -numa dist,src=2,dst=3,val=12										\
				-kernel $KERNEL_IMAGE															\
				-append "root=/dev/ram rdinit=/linuxrc console=ttyS0 nokaslr loglevel=8 kgdboc=ttyS0,115200 sched_debug=1 psi=1 psi_v1=1" -nographic	\
				-initrd $INITRDFS	\
				--virtfs local,id=kmod_dev,path=$VIRFS,security_model=none,mount_tag=kmod_mount \
				$DBG ;;
		x86)
		qemu-system-i386 -kernel $KERNEL_IMAGE -smp 4 -m 2048M\
				 -append "/root=/dev/ram rdinit=/linuxrc console=ttyS0 loglevel=8" -nographic \
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
		qemu-system-aarch64 -M virt,gic-version=3 -cpu cortex-a57 -machine type=virt \
				    -m 20480M -smp 4 -kernel $KERNEL_IMAGE \
				    -append "root=/dev/ram rdinit=/linuxrc console=ttyAMA0" -nographic \
				    -initrd $INITRDFS \
				    --fsdev local,id=kmod_dev,path=$VIRFS,security_model=none -device virtio-9p-device,fsdev=kmod_dev,mount_tag=kmod_mount \
				    $DBG ;;
		*)
			echo "Unknown ARCH"
			exit 0
			;;
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

	if [ $TO_DO = "build" ]; then
		qemu_build_kernel
	elif [ $TO_DO = "run" ]; then
		qemu_run_kernel
	elif [ $TO_DO = "debug" ]; then
		qemu_debug_kernel
	fi
}

#=====================
# MAIN Functions here
#=====================

if [ $# -gt 4 ]; then
	show_usage
	exit 0
fi

if [ -z "$KERNEL_NAME" ];then
	KERNEL_NAME=src
fi

for OPT #in $@
do
	OPTARG=$(expr "x$OPT" : 'x[^=]*=\(.*\)')

	case $OPT in
		--arch=*|-a=*)
			ARCH=$OPTARG
			;;
		--source=*|-s=*)
			KERNEL_SOURCE=$OPTARG
			;;
		--build=*|-b=*)
			KERNEL_BUILD=$OPTARG
			;;
		--todo=*)
			TO_DO=$OPTARG
			;;
		--debug=*)
			DBG="-s"
			;;
		?)
			show_usage
			exit 0
			;;
	esac
done


# Build/Run Kernel Directory
#KERNEL_SOURCE use --source
BUILD_ROOT_DIR=$(cd $(dirname $KERNEL_SOURCE) ; pwd)
#BUILD_OUTPUT_DIR=$KERNEL_BUILD
BUILD_OUTPUT_DIR=$BUILD_ROOT_DIR/build/$ARCH/qemu
BUILD_KERNEL_DIR=$BUILD_ROOT_DIR/$KERNEL_NAME
BUILD_PATCH_DIR=$BUILD_ROOT_DIR/patch
VMLINUX_FILE=$BUILD_OUTPUT_DIR/vmlinux
CONFIG_FILE=$BUILD_OUTPUT_DIR/.config

# Qemu environment
QEMU_SYSTEM_DIR=/opt/software/toolchain/qemu/bin

# This Project Directory for scripts/filesystem/virtiofs
CURR_SCRIPT_PATH=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)
ROOT_SCRIPT_DIR=$CURR_SCRIPT_PATH/..
INITRDFS=$ROOT_SCRIPT_DIR/filesystem/initrdfs/$ARCH/rootfs.cpio.gz
VIRFS=$ROOT_SCRIPT_DIR/filesystem/9p_virfs/$ARCH
BAKCUP_DIR=$ROOT_SCRIPT_DIR/backup/$ARCH


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

running_linux_kernel $TO_DO $ARCH $BUILD_ROOT_DIR
