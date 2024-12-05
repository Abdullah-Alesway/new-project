
#!/bin/bash

# Bash script to install and set up Frigate NVR

# Exit on error
set -e

echo "Installing Podman..."
sudo dnf install -y podman

echo "Creating necessary directories for Frigate..."
sudo mkdir -p /var/frigate/media /var/frigate/config

echo "Setting up Frigate configuration..."
CONFIG_FILE="/var/frigate/config/config.yml"
if [[ ! -f "$CONFIG_FILE" ]]; then
  sudo tee "$CONFIG_FILE" > /dev/null <<EOF
mqtt:
  enabled: False

cameras:
  dummy_camera: # <--- this will be changed to your actual camera later
    enabled: False
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:554/rtsp
          roles:
            - detect
EOF
else
  echo "Configuration file already exists: $CONFIG_FILE"
fi

echo "Creating systemd configuration for Frigate..."
SYSTEMD_FILE="/etc/containers/systemd/frigate.container"
if [[ ! -f "$SYSTEMD_FILE" ]]; then
  sudo mkdir -p /etc/containers/systemd
  sudo tee "$SYSTEMD_FILE" > /dev/null <<EOF
[Unit]
Description=Frigate video recorder
After=network-online.target

[Container]
ContainerName=frigate
Network=host
Environment=FRIGATE_RTSP_PASSWORD="password"
Environment=FRIGATE_MQTT_USER="user"
Environment=FRIGATE_MQTT_PASSWORD="pass"
Volume=/var/frigate/media:/media
Volume=/var/frigate/config:/config
Volume=/etc/localtime:/etc/localtime:ro
Mount=type=tmpfs,target=/tmp/cache,tmpfs-size=1000000000
ShmSize=64m
Image=ghcr.io/blakeblackshear/frigate:stable

[Service]
Restart=always
TimeoutStartSec=900

[Install]
WantedBy=multi-user.target
EOF
else
  echo "Systemd configuration file already exists: $SYSTEMD_FILE"
fi

echo "Adding firewall rules for Frigate..."
sudo firewall-cmd --permanent --zone=public --add-port=8971/tcp
sudo firewall-cmd --permanent --zone=public --add-port=5000/tcp
sudo firewall-cmd --permanent --zone=public --add-port=8554/tcp
sudo firewall-cmd --permanent --zone=public --add-port=8555/tcp
sudo firewall-cmd --reload

echo "Setting SELinux permissions for Frigate directories..."
sudo chcon -Rt container_file_t /var/frigate

echo "Setup complete. Enable and start the Frigate container with:"
echo "  podman generate systemd --new frigate -f && sudo systemctl enable --now containers-frigate.service"
