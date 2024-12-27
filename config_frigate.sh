#!/bin/bash

CONFIG_FILE="/var/frigate/config/config.yml"

# Create the base configuration file
cat <<EOL > "$CONFIG_FILE"
mqtt:
  enabled: false

database:
  path: /config/frigate.db

logger:
  logs:
    frigate.stats.emitter: debug

ffmpeg:
  hwaccel_args: preset-vaapi
  output_args:
    record: preset-record-generic-audio-aac

detectors:
  ov:
    type: openvino
    device: CPU

model:
  width: 300
  height: 300
  input_tensor: nhwc
  input_pixel_format: bgr
  path: /openvino-model/ssdlite_mobilenet_v2.xml
  labelmap_path: /openvino-model/coco_91cl_bkgr.txt

birdseye:
  enabled: true
  mode: continuous
  width: 1920
  height: 1080
  restream: true

objects:
  track:
    - person
    - cat
    - dog

go2rtc:
  streams:
EOL

# Add camera streams
while true; do
  read -e -p "Enter camera name (type 'done' to finish): " CAM_NAME
  if [[ "$CAM_NAME" == "done" ]]; then
    break
  fi

  read -e -p "Enter RTSP URL for $CAM_NAME: " RTSP_URL

  # Append camera stream to the configuration
  cat <<EOL >> "$CONFIG_FILE"
    $CAM_NAME:
      - $RTSP_URL
EOL

done

# Add cameras section
cat <<EOL >> "$CONFIG_FILE"
cameras:
EOL

# Add camera configurations
while true; do
  read -e -p "Enter camera name for configuration (type 'done' to finish): " CAM_NAME
  if [[ "$CAM_NAME" == "done" ]]; then
    break
  fi

  cat <<EOL >> "$CONFIG_FILE"
  $CAM_NAME:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/$CAM_NAME?video&audio
          input_args: preset-rtsp-restream
          roles:
            - detect
            - record
    snapshots:
      enabled: true
    record:
      enabled: true
      retain:
        days: 14
        mode: all
      events:
        retain:
          default: 90
          mode: motion
EOL

done


cat <<EOL >> "$CONFIG_FILE"
version: 0.14
EOL

echo "Configuration file created at $CONFIG_FILE"

