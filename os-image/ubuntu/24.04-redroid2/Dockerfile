# cocoon OCI image: Ubuntu 24.04 + redroid via systemd-nspawn (no Docker).
#
# Architecture: Host → cocoon VM (this image) → systemd-nspawn → Android (redroid)
# Remote access: scrcpy/adb connects to <vm-ip>:5555
#
# vs Docker-based variant (24.04-redroid):
# - No Docker daemon (no dockerd/containerd/vfs overhead)
# - Android rootfs baked into image (no first-boot pull needed)
# - systemd-nspawn for lightweight containment
#
# Uses linux-image-generic (not virtual) because binder_linux is only
# available in linux-modules-extra-*-generic.
#
# Notes:
# - nspawn runs without --boot; explicitly invokes /init so Android init
#   is PID 1 and receives androidboot.* via /proc/self/cmdline
# - --capability=all: equivalent to Docker --privileged for Android init
# - No --private-network: container shares VM network (like --network=host)
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
    systemd-container \
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
    # binder_linux loaded at boot; use_memfd=1 replaces ashmem
    printf "binder_linux\n" > /etc/modules-load.d/redroid.conf && \
    echo 'options binder_linux devices="binder,hwbinder,vndbinder"' > /etc/modprobe.d/redroid.conf && \
    # --- redroid nspawn service ---
    # No --boot: explicitly run /init so androidboot.* params appear in
    # /proc/self/cmdline (same mechanism as Docker CMD).
    # --capability=all: Android init needs full caps (equivalent to --privileged).
    # --keep-unit: run in service's own cgroup (no transient scope).
    # --register=no + --link-journal=no: skip machined/journal integration.
    printf '[Unit]\nDescription=Redroid Android Container (nspawn)\nAfter=systemd-modules-load.service network.target\nRequires=systemd-modules-load.service\n\n[Service]\nType=simple\nExecStartPre=-/bin/mkdir -p /dev/binderfs\nExecStartPre=-/bin/mount -t binder binder /dev/binderfs\nExecStart=/usr/bin/systemd-nspawn --machine=android --directory=/var/lib/machines/android_os --capability=all --keep-unit --bind=/dev/binderfs --bind=/dev/fuse --register=no --link-journal=no /init androidboot.redroid_gpu_mode=guest androidboot.use_memfd=1 androidboot.redroid_width=1080 androidboot.redroid_height=1920 androidboot.redroid_dpi=320\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/redroid-nspawn.service && \
    systemctl enable redroid-nspawn && \
    # --- access ---
    echo 'root:cocoon' | chpasswd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=android-rootfs / /var/lib/machines/android_os/

CMD ["/sbin/init"]
