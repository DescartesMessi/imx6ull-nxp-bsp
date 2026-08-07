#!/bin/bash
###############################################################################
# File       : create_rootfs.sh
# Author     : Pointer
# Platform   : i.MX6ULL JJL
#
# Description:
#
# 1. Generate complete Linux root filesystem
# 2. Copy ARM runtime libraries
# 3. Configure mdev
# 4. Generate basic system files
#
###############################################################################
set -u
###############################################################################
# Environment
###############################################################################

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
ROOTFS_DIR="${PROJECT_ROOT}/deploy/nfs/rootfs"
###############################################################################
# Functions
###############################################################################

log_info()
{
    echo -e "\033[32m[INFO]\033[0m $1"
}
die()
{
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}
###############################################################################
# Start
###############################################################################

echo "======================================"
echo " Create i.MX6ULL RootFS"
echo "======================================"
echo "Rootfs : ${ROOTFS_DIR}"

###############################################################################
# Clean rootfs
###############################################################################

log_info "Prepare rootfs directory"
mkdir -p ${ROOTFS_DIR}

###############################################################################
# Create directories
###############################################################################

log_info "Create filesystem directories"
mkdir -p \
${ROOTFS_DIR}/dev \
${ROOTFS_DIR}/proc \
${ROOTFS_DIR}/sys \
${ROOTFS_DIR}/tmp \
${ROOTFS_DIR}/mnt \
${ROOTFS_DIR}/root \
${ROOTFS_DIR}/etc/init.d \
${ROOTFS_DIR}/lib \
${ROOTFS_DIR}/usr/lib

###############################################################################
# Copy dynamic libraries
###############################################################################

log_info "Copy ARM runtime libraries"
SYSROOT=$(arm-linux-gnueabihf-gcc -print-sysroot)
if [ ! -d "${SYSROOT}" ]; then

    die "Cannot find ARM sysroot"

fi

# libc libraries

cp -a ${SYSROOT}/lib/*.so* \
${ROOTFS_DIR}/lib/ \
|| die "Copy libc library failed"

# gcc runtime libraries

cp -a ${SYSROOT}/usr/lib/*.so* \
${ROOTFS_DIR}/usr/lib/ \
|| die "Copy usr libraries failed"

###############################################################################
# Fix dynamic loader
###############################################################################

log_info "Fix ld-linux-armhf.so.3"
rm -f ${ROOTFS_DIR}/lib/ld-linux-armhf.so.3
LD_SO=$(find ${SYSROOT} \
-name ld-linux-armhf.so.3 | head -n 1)

if [ -z "${LD_SO}" ];then

    die "Cannot find ld-linux-armhf.so.3"

fi
cp ${LD_SO} \
${ROOTFS_DIR}/lib/

###############################################################################
# Create /etc files
###############################################################################

log_info "Create system configuration"
cat > ${ROOTFS_DIR}/etc/passwd << EOF
root:x:0:0:root:/root:/bin/sh
EOF

cat > ${ROOTFS_DIR}/etc/group << EOF
root:x:0:
EOF

cat > ${ROOTFS_DIR}/etc/profile << EOF
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
EOF

echo "imx6ull-jjl" \
> ${ROOTFS_DIR}/etc/hostname

###############################################################################
# Init configuration
###############################################################################
log_info "Create init scripts"
cat > ${ROOTFS_DIR}/etc/inittab << EOF
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::restart:/sbin/init
EOF
cat > ${ROOTFS_DIR}/etc/init.d/rcS << EOF
#!/bin/sh
echo "================================="
echo " i.MX6ULL JJL Linux Boot"
echo "================================="
mount -t proc proc /proc
mount -t sysfs sysfs /sys
echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s
EOF
chmod +x ${ROOTFS_DIR}/etc/init.d/rcS
###############################################################################
# Finish
###############################################################################
echo ""
echo "======================================"
echo " RootFS Generate Finished"
echo "======================================"
du -sh ${ROOTFS_DIR}
exit 0