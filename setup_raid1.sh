#!/bin/bash

# Variables
RAID_DEVICE="/dev/md0"
MOUNT_POINT="/mnt/NAS1"

# Functions
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root or with sudo."
        exit 1
    fi
}

install_mdadm() {
    if ! command -v mdadm &>/dev/null; then
        echo "Installing mdadm package..."
        dnf install -y mdadm || {
            echo "Error: Failed to install mdadm. Exiting."
            exit 1
        }
    else
        echo "mdadm is already installed."
    fi
}

display_devices() {
    echo "Available block devices:"
    lsblk
}

get_devices() {
    while true; do
        read -rp "Enter the first device for RAID (e.g., /dev/sdX): " DEV1
        read -rp "Enter the second device for RAID (e.g., /dev/sdY): " DEV2

        if [[ -b $DEV1 && -b $DEV2 && $DEV1 != $DEV2 ]]; then
            break
        else
            echo "Invalid devices or devices are the same. Please try again."
        fi
    done
}

get_username() {
    while true; do
        read -rp "Enter the username that should have primary access to the RAID device: " USERNAME
        if id "$USERNAME" &>/dev/null; then
            break
        else
            echo "Error: User $USERNAME does not exist. Please create the user first."
        fi
    done
}

prepare_devices() {
    echo "Preparing devices $DEV1 and $DEV2..."
    for DEV in "$DEV1" "$DEV2"; do
        echo "Formatting $DEV..."
        mkfs.ext4 "$DEV" || {
            echo "Error: Failed to format $DEV. Exiting."
            exit 1
        }
        echo "Clearing RAID metadata on $DEV..."
        mdadm --zero-superblock "$DEV" || {
            echo "Error: Failed to clear RAID metadata on $DEV."
        }
    done
}

create_raid() {
    if [ -e "$RAID_DEVICE" ]; then
        echo "Error: RAID device $RAID_DEVICE already exists. Aborting to prevent data loss."
        exit 1
    fi

    echo "Creating RAID1 array..."
    mdadm --create "$RAID_DEVICE" --level=1 --raid-devices=2 "$DEV1" "$DEV2" || {
        echo "Error: Failed to create RAID array. Exiting."
        exit 1
    }
}

check_raid_status() {
    echo "Checking RAID status..."
    cat /proc/mdstat || echo "Error: Could not read RAID status."
}

save_raid_config() {
    echo "Saving RAID configuration to /etc/mdadm.conf..."
    mdadm --detail --scan >> /etc/mdadm.conf || {
        echo "Error: Failed to save RAID configuration."
        exit 1
    }
}

update_initramfs() {
    echo "Updating initramfs..."
    dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r) || {
        echo "Error: Failed to update initramfs."
        exit 1
    }
}

format_raid_device() {
    echo "Formatting RAID device $RAID_DEVICE..."
    mkfs.ext4 "$RAID_DEVICE" || {
        echo "Error: Failed to format RAID device. Exiting."
        exit 1
    }
}

mount_raid() {
    echo "Creating and mounting RAID device..."
    mkdir -p "$MOUNT_POINT" || {
        echo "Error: Failed to create mount point $MOUNT_POINT. Exiting."
        exit 1
    }
    echo "$RAID_DEVICE $MOUNT_POINT ext4 defaults 0 0" >> /etc/fstab
    systemctl daemon-reload || {
        echo "Error: Failed to reload systemd daemon. Exiting."
        exit 1
    }
    mount "$MOUNT_POINT" || {
        echo "Error: Failed to mount $RAID_DEVICE. Exiting."
        exit 1
    }
}

set_permissions() {
    echo "Setting ownership and permissions for $MOUNT_POINT..."
    chown "$USERNAME:$USERNAME" "$MOUNT_POINT" || {
        echo "Error: Failed to set ownership."
        exit 1
    }
    chmod 775 "$MOUNT_POINT" || {
        echo "Error: Failed to set permissions."
        exit 1
    }
    umount "$MOUNT_POINT"
    systemctl daemon-reload || {
        echo "Error: Failed to reload systemd daemon. Exiting."
        exit 1
    }
    mount "$MOUNT_POINT" || {
        echo "Error: Failed to remount $MOUNT_POINT."
        exit 1
    }
}

# Main script
check_root
install_mdadm
display_devices
get_devices
get_username
prepare_devices
create_raid
check_raid_status
save_raid_config
update_initramfs
format_raid_device
mount_raid
set_permissions

echo "RAID1 device setup completed successfully for user $USERNAME!"
