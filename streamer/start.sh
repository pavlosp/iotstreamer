#!/bin/bash
set -e

mkdir -p /var/run/pulse
chown root:root /var/run/pulse

# Default values
export SOUND_DEVICE_NAME=${SOUND_DEVICE_NAME:-"Raspberry Pi Streamer"}
export SOUND_EQ=${SOUND_EQ:-"0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"}

# Route alsa to pulseaudio by writing a basic asound.conf if needed
cat <<EOF > /etc/asound.conf
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOF

# Wait for PulseAudio to be fully initialized before applying runtime configs
# Actually, since we use --system, we will append to system.pa before supervisor starts it.
echo "load-module module-ladspa-sink sink_name=eq sink_properties=device.description=\"Equalizer\" plugin=mbeq_1197 label=mbeq control=$SOUND_EQ" >> /etc/pulse/system.pa
echo "set-default-sink eq" >> /etc/pulse/system.pa
echo "set-sink-volume eq 65536" >> /etc/pulse/system.pa

echo "Starting configuration for Streamer..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
