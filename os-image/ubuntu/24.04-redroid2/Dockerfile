# cocoon OCI image: Ubuntu 24.04 + redroid via unshare+chroot (no Docker, no nspawn).
#
# Architecture: Host → cocoon VM (this image) → unshare+chroot → Android (redroid)
# Remote access: scrcpy/adb connects to <vm-ip>:5555
#
# vs Docker-based variant (24.04-redroid):
# - No Docker daemon (no dockerd/containerd/vfs overhead)
# - Android rootfs baked into image (no first-boot pull needed)
# - Minimal namespace isolation (PID + mount only), full /dev access
#
# Uses linux-image-generic (not virtual) because binder_linux is only
# available in linux-modules-extra-*-generic.
#
# Notes:
# - unshare --pid --mount --fork + chroot runs Android init as PID 1
#   in its own PID namespace, with shared host /dev (loop, dm, fuse all available)
# - androidboot.* params passed as args to /init (read via /proc/self/cmdline)
# - No network namespace: container shares VM network (port 5555 on VM IP)
# - binder_linux loaded at boot via systemd-modules-load

FROM redroid/redroid:16.0.0-latest AS android-rootfs
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=secret,id=cocoon_overlay \
    --mount=type=secret,id=cocoon_network \
    apt-get update && apt-get install -y --no-install-recommends \
    linux-image-generic \
    initramfs-tools \
    systemd systemd-sysv systemd-timesyncd systemd-resolved \
    udev kmod iproute2 iputils-ping curl ca-certificates net-tools \
    htop ncdu nload tree \
    && \
    # Install extra modules for binder — needs KVER from installed kernel.
    apt-get install -y --no-install-recommends \
        linux-modules-extra-$(ls /lib/modules/ | head -1) \
    && \
    # --- cocoon initramfs hooks ---
    cp /run/secrets/cocoon_overlay /etc/initramfs-tools/scripts/cocoon-overlay && \
    chmod 0755 /etc/initramfs-tools/scripts/cocoon-overlay && \
    cp /run/secrets/cocoon_network /etc/initramfs-tools/scripts/init-bottom/cocoon-network && \
    chmod 0755 /etc/initramfs-tools/scripts/init-bottom/cocoon-network && \
    printf "erofs\noverlay\next4\nvirtio_blk\nvirtio_pci\nvirtio_ring\nvirtio_net\n" >> /etc/initramfs-tools/modules && \
    sed -i 's/^COMPRESS=.*/COMPRESS=gzip/' /etc/initramfs-tools/initramfs.conf && \
    echo 'IP=dhcp' >> /etc/initramfs-tools/initramfs.conf && \
    update-initramfs -u -k all && \
    ls /boot/vmlinuz-* /boot/initrd.img-* && \
    # --- systemd ---
    truncate -s 0 /etc/fstab && \
    systemctl mask systemd-fsck-root.service systemd-remount-fs.service systemd-fsck@.service && \
    systemctl enable systemd-networkd systemd-resolved systemd-timesyncd && \
    mkdir -p /etc/systemd/network && \
    printf "[Match]\nName=e* v*\n[Network]\nDHCP=yes\n" > /etc/systemd/network/20-wired.network && \
    # --- binder kernel module ---
    printf "binder_linux\n" > /etc/modules-load.d/redroid.conf && \
    echo 'options binder_linux devices="binder,hwbinder,vndbinder"' > /etc/modprobe.d/redroid.conf && \
    # --- redroid launch script ---
    printf '#!/bin/sh\nset -e\nROOTFS=/var/lib/machines/android_os\nmount --make-rprivate /\nmount --bind /dev "$ROOTFS/dev"\nmount -t proc proc "$ROOTFS/proc"\nmount -t sysfs sysfs "$ROOTFS/sys"\nmkdir -p "$ROOTFS/dev/binderfs"\nmount -t binder binder "$ROOTFS/dev/binderfs" 2>/dev/null || true\nexec chroot "$ROOTFS" /init \\\n  androidboot.redroid_gpu_mode=guest \\\n  androidboot.use_memfd=1 \\\n  androidboot.redroid_width=1080 \\\n  androidboot.redroid_height=1920 \\\n  androidboot.redroid_dpi=320\n' > /usr/local/bin/redroid-start.sh && \
    chmod 0755 /usr/local/bin/redroid-start.sh && \
    # --- redroid systemd service ---
    printf '[Unit]\nDescription=Redroid Android Container\nAfter=systemd-modules-load.service network.target\nRequires=systemd-modules-load.service\n\n[Service]\nType=simple\nExecStart=/usr/bin/unshare --pid --mount --fork -- /usr/local/bin/redroid-start.sh\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/redroid.service && \
    systemctl enable redroid && \
    # --- access ---
    echo 'root:cocoon' | chpasswd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=android-rootfs / /var/lib/machines/android_os/

CMD ["/sbin/init"]
