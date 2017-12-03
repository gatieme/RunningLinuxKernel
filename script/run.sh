#!/bin/bash
run_kernel()
{
if [ $ARCH == "x86_64" ]; then
	/opt/qemu-2.9.0/bin/qemu-system-x86_64				\
		-smp 2 -m 2048						\
		-kernel ${BUILD_KERNEL_DIR}/arch/x86_64/boot/bzImage	\
		-append "rdinit=/linuxrc console=ttyS0" -nographic
elif [ $ARCH == "arm64" ]; then
	/opt/qemu/2.9.0/bin/qemu-system-aarch64				\
		-cpu cortex-a57 -smp 2 -m 2048 -machine virt		\
		-kernel ${BUILD_KERNEL_DIR}/arch/arm64/boot/Image	\
		-append "rdinit=/linuxrc console=ttyAMA0" -nographic
elif [ $ARCH == "arm" ]; then
	/opt/qemu-2.9.0/bin/qemu-system-arm				\
		-M vexpress-a9 -smp 2 -m 1024M				\
		-kernel ${BUILD_KERNEL_DIR}/arch/arm/boot/zImage	\
		-append "rdinit=/linuxrc console=ttyAMA0" -nographic	\
		-dtb ${BUILD_KERNEL_DIR}/arch/arm/boot/dts/vexpress-v2p-ca9.dtb
fi
}

build_kernel()
{
if [ $ARCH == "x86_64" ]; then
	make -j20
elif [ $ARCH == "arm64" ]; then
	export ARCH=arm64
	export CROSS_COMPILE=/opt/arm/toolschain/linaro/gcc-linaro-7.1.1-2017.08-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
elif [ $ARCH == "arm" ]; then
	export ARCH=arm
	export CROSS_COMPILE=arm-linux-gnueabi-
fi
}


show_usage( )
{
	echo "Usage :"
	echo "\tsh $0 TODO ARCH BUILD_KERNEL_ROOT"
}

if [ $# != 3 ]; then
	show_usage
	exit 0
fi

TODO=$1
ARCH=$2
BUILD_KERNEL_ROOT=$3
BUILD_KERNEL_DIR=${BUILD_KERNEL_ROOT}/build/$ARCH


if [ $TODO == "run" ]; then
	run_kernel
elif [ $TODO == "build" ]; then
	build_kernel
else
	echo "Unknown to do what thing..."
	exit 0
fi



