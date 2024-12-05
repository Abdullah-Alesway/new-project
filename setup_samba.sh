#!/bin/bash

# Prompt for the shared folder path
read -p "Enter the full path for the shared folder (e.g., /NVR/Frigate): " SHARED_FOLDER
if [ -z "$SHARED_FOLDER" ]; then
    echo "Shared folder path cannot be empty. Exiting."
    exit 1
fi

echo "Installing Samba, Samba client, and CIFS utilities..."
dnf install -y samba samba-client cifs-utils

echo "Starting and enabling Samba services..."
systemctl start smb
systemctl start nmb
systemctl enable smb
systemctl enable nmb

echo "Configuring the firewall for Samba..."
firewall-cmd --permanent --zone=public --add-service=samba
firewall-cmd --reload

echo "Creating shared folder at $SHARED_FOLDER..."
mkdir -p "$SHARED_FOLDER"

echo "Setting permissions for the shared folder..."
chown -R nobody:nobody "$SHARED_FOLDER"
chmod -R 0775 "$SHARED_FOLDER"

echo "Backing up the existing Samba configuration..."
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

echo "Configuring Samba shared folder in smb.conf..."
cat <<EOF >> /etc/samba/smb.conf

[$(basename "$SHARED_FOLDER")]
   path = $SHARED_FOLDER
   browseable = yes
   writable = yes
   guest ok = no
   read only = no
   valid users = $SAMBA_USER
   create mask = 0664
   directory mask = 0775
EOF


read -p "Enter the Samba username to grant access (e.g., nvruser): " SAMBA_USER

if [ -z "$SAMBA_USER" ]; then
    echo "Samba username cannot be empty. Exiting."
    exit 1
fi
if pdbedit -L | cut -d: -f1 | grep -qw "$SAMBA_USER"; then
    echo "Samba user '$SAMBA_USER' already exists."
else
    echo "Samba user '$SAMBA_USER' does not exist. Creating user..."
    
    # Add a system user if it does not already exist
    if ! id "$SAMBA_USER" &>/dev/null; then
        sudo useradd -M "$SAMBA_USER"
        echo "System user '$SAMBA_USER' created."
    else
        echo "System user '$SAMBA_USER' already exists."
    fi

    # Set Samba password for the user
    sudo smbpasswd -a "$SAMBA_USER"
    if [ $? -eq 0 ]; then
        echo "Samba user '$SAMBA_USER' has been created and granted access."
    else
        echo "Failed to create Samba user '$SAMBA_USER'."
        exit 2
    fi
fi


echo "Setting SELinux booleans for Samba..."
setsebool -P samba_enable_home_dirs on
setsebool -P samba_export_all_rw on

echo "Restarting Samba services..."
systemctl restart smb
systemctl restart nmb

echo "Samba file sharing setup completed!"

