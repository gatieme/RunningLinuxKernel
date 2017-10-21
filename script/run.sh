#!/bin/bash
ARCH=$1
BUILD_KERNEL_ROOT=$2
BUILD_KERNEL_DIR=${BUILD_KERNEL_ROOT}/build/$ARCH

if [ $ARCH == "x86_64" ]; then
	qemu-system-x86_64 -smp 2 -m 2048				\
		-kernel ${BUILD_KERNEL_DIR}/arch/x86_64/boot/bzImage	\
		-append "rdinit=/linuxrc console=ttyS0" -nographic
elif [ $ARCH == "arm64" ]; then
	qemu-system-aarch64 -machine virt -cpu cortex-a57		\
		-machine type=virt -nographic -m 2048 –smp 4		\
		-kernel ${BUILD_KERNEL_DIR}/arch/arm64/boot/Image	\
		--append "rdinit=/linuxrc console=ttyAMA0"
fi
