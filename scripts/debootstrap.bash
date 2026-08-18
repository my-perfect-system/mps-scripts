#!/bin/bash

# set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# export EFI_TARGET=""
# export PART_TARGET=""
# export PART_TARGET_UUID=""
# export PART_EFI_UUID=""
export EFI_TARGET="/dev/disk/by-id/nvme-WDS200T1X0E-00AFY0_2053HP442710_1-part1"
export PART_TARGET="/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_224519801647-part6"
export PART_TARGET_UUID="248f5559-8fe2-400e-b2dc-4f67f47ded06"
export PART_EFI_UUID="5009-FF6F"

export DIR_TARGET="$PWD/target"
export FILE_CHROOT_INIT="chroot_init.bash"

export DEBOOTSTRAP_ARCH="amd64"
export DEBOOTSTRAP_CODENAME="trixie"
export DEBOOTSTRAP_URL="http://deb.debian.org/debian/"
export DEBOOTSTRAP_HOSTNAME="foobar"
export DEBOOTSTRAP_DOMAIN="lokal"
export DEBOOTSTRAP_ROOTPW='FOObarBAZ!!2026'
export DEBOOTSTRAP_LOCALE="en_US"
export DEBOOTSTRAP_LOCALE_ENC="UTF-8"
export DEBOOTSTRAP_LOCALE_STR="$DEBOOTSTRAP_LOCALE.$DEBOOTSTRAP_LOCALE_ENC"
export DEBOOTSTRAP_KEYBOARD_LAYOUT="de"
export DEBOOTSTRAP_TIME_SRV="10.23.42.1"
export DEBOOTSTRAP_TIME_ZONE="Europe/Berlin"


prepare_target() {
    echo "==> Preparing target"

    mkdir -p "$DIR_TARGET"

    if [ "$PART_TARGET" != "" ] && [ "$EFI_TARGET" != "" ]; then
        if ! mountpoint -q "$DIR_TARGET"; then
            mount "$PART_TARGET" "$DIR_TARGET"
        fi

        mkdir -p "$DIR_TARGET/boot/efi"

        if ! mountpoint -q "$DIR_TARGET/boot/efi"; then
            mount "$EFI_TARGET" "$DIR_TARGET/boot/efi"
        fi
    else
        echo "==> No partitions selected! Running only in local folder..."
    fi
}

run_debootstrap() {
    echo "==> Running debootstrap"

    set +euo pipefail
    debootstrap \
        --arch "$DEBOOTSTRAP_ARCH" \
        "$DEBOOTSTRAP_CODENAME" \
        "$DIR_TARGET" \
        "$DEBOOTSTRAP_URL"
    set -euo pipefail
    cp /etc/hosts "$DIR_TARGET/etc/hosts"
}

configure_target() {
    echo "==> Configuring target"

    if [ "$PART_TARGET_UUID" != "" ] && [ "$PART_EFI_UUID" != "" ]; then
        cat > "$DIR_TARGET/etc/fstab" <<EOF
UUID=$PART_TARGET_UUID / ext4 defaults 0 1
UUID=$PART_EFI_UUID /boot/efi vfat umask=0077 0 1
EOF
    else
        echo "==> No partitions selected! Running without fstab config..."
    fi

    cat > "$DIR_TARGET/etc/hostname" <<EOF
$DEBOOTSTRAP_HOSTNAME
EOF

    if [ "$DEBOOTSTRAP_HOSTNAME" != "" ] ; then
        cat > "$DIR_TARGET/etc/hosts" <<EOF
127.0.0.1       localhost
127.0.1.1       $DEBOOTSTRAP_HOSTNAME.$DEBOOTSTRAP_DOMAIN $DEBOOTSTRAP_HOSTNAME

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
    else
        echo "==> No hostname specified! Running without /etc/hosts config..."
    fi
}
    
chroot_mount() {
    echo "==> Preparing chroot mounts"

    mount --bind /dev "$DIR_TARGET/dev"
    mount --bind /dev/pts "$DIR_TARGET/dev/pts"

    mount -t proc proc "$DIR_TARGET/proc"
    mount -t sysfs sysfs "$DIR_TARGET/sys"

    mount --bind /run "$DIR_TARGET/run"

    cp -L /etc/resolv.conf "$DIR_TARGET/etc/resolv.conf"
}

chroot_exec() {
    echo "==> Configuring Debian inside chroot"

    cat > "$DIR_TARGET/$FILE_CHROOT_INIT" <<'EOFFILE'
#!/bin/bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "==> Updating package lists"
apt update

echo "==> Installing base packages"
apt install -y \
    git \
    vim \
    make \
    ansible \
    sudo \
    openssh-server \
    vlan \
    ifenslave \
    isc-dhcp-client \
    net-tools \
    bridge-utils \
    tcpdump \
    systemd \
    systemd-sysv \
    dbus \
    linux-image-amd64 \
    initramfs-tools \
    grub-efi-amd64 \
    shim-signed \
    os-prober

echo "==> Installing amd packages"
apt install -y \
    xserver-xorg-video-amdgpu

echo "==> Setting root password"
printf '%s\n' "root:$DEBOOTSTRAP_ROOTPW" | chpasswd

if mountpoint -q "/boot/efi"; then
    echo "==> Installing GRUB"
    grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=$DEBOOTSTRAP_HOSTNAME \
        --recheck
    update-grub
fi

echo "==> Configure Console, Locale and keyboard..."

echo "$DEBOOTSTRAP_TIME_ZONE" > /etc/timezone
timedatectl set-timezone "$DEBOOTSTRAP_TIME_ZONE"
apt install -y chrony
cat <<EOF >/etc/chrony/conf.d/99-local-server.conf
pool 2.debian.pool.ntp.org offline
server $DEBOOTSTRAP_TIME_SRV iburst
bindaddress 127.0.0.1
EOF
echo "DAEMON_OPTS='-F 1 -4'" > /etc/default/chrony
systemctl restart chrony

# Locale
apt install -y locales
cat <<EOF > /etc/default/locale
LANG=$DEBOOTSTRAP_LOCALE_STR
LANGUAGE=$DEBOOTSTRAP_LOCALE_STR
LC_ALL=$DEBOOTSTRAP_LOCALE_STR
EOF
echo "$DEBOOTSTRAP_LOCALE_STR $DEBOOTSTRAP_LOCALE_ENC" >> /etc/locale.gen
locale-gen
echo "locales locales/default_environment_locale select $DEBOOTSTRAP_LOCALE_STR" \
    | debconf-set-selections
dpkg-reconfigure -f noninteractive locales

# Keyboard
cat <<EOF > /etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="$DEBOOTSTRAP_KEYBOARD_LAYOUT"
XKBVARIANT="nodeadkeys"
XKBOPTIONS="compose:menu"
BACKSPACE="guess"
EOF
apt-get install -y keyboard-configuration
dpkg-reconfigure -f noninteractive keyboard-configuration

# console
cat <<EOF > /etc/default/console-setup
ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="$DEBOOTSTRAP_LOCALE_ENC"
CODESET="Lat15"
FONTFACE="Terminus"
FONTSIZE="8x16"
VIDEOMODE=
EOF
apt-get install -y console-setup
dpkg-reconfigure -f noninteractive console-setup
systemctl enable console-setup.service
systemctl restart console-setup.service


echo "==> Install mps"
mkdir -p /root/repo/github/my-perfect-system
cd /root/repo/github/my-perfect-system
[[ -d mps-examples ]] || git clone https://github.com/my-perfect-system/mps-examples.git
[[ -d mps-collections ]] || git clone https://github.com/my-perfect-system/mps-collections.git
cd mps-examples/inventories/home
make -C ../../ install
sed "s/hosts.ini/local.ini/g" -i ansible.cfg
ansible-playbook bootstrap.yml
ansible-playbook workstation.yml

echo "==> Installed kernel:"
ls -lh /boot/vmlinuz* /boot/initrd.img*
sync
sync

EOFFILE

    chmod +x "$DIR_TARGET/$FILE_CHROOT_INIT"

    chroot "$DIR_TARGET" /bin/bash "/$FILE_CHROOT_INIT"
}
chroot_bash() {
    chroot "$DIR_TARGET" /bin/bash
}
chroot_unmount() {
    echo "==> Unmounting chroot filesystems"

    umount "$DIR_TARGET/run"
    umount "$DIR_TARGET/sys"
    umount "$DIR_TARGET/proc"
    umount "$DIR_TARGET/dev/pts"
    umount "$DIR_TARGET/dev"

    if [ "$EFI_TARGET" != "" ]; then
        umount "$DIR_TARGET/boot/efi"
    else
        echo "==> No partitions selected! Umount efi not needed..."
    fi
}

finalize_target() {
    echo "==> Finalizing target"

    if [ "$PART_TARGET" != "" ] ; then
        umount "$DIR_TARGET"
    else
        echo "==> No partitions selected! Umount target folder not needed..."
    fi
}

action_chroot_install() {
    prepare_target
    run_debootstrap
    configure_target
    chroot_mount
    chroot_exec
    chroot_unmount
    finalize_target
}
action_chroot_bash() {
    prepare_target
    chroot_mount
    chroot_bash
    chroot_unmount
    finalize_target
}
action_chroot_unmount() {
    set +euo pipefail
    chroot_unmount
    finalize_target
    set -euo pipefail
}

action_chroot_unmount
# action_chroot_install
action_chroot_bash



