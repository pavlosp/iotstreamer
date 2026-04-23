#!/bin/bash
set -e

# Remove any internal conflicting dbus or avahi PIDs
rm -rf /var/run/dbus/* /var/run/avahi-daemon/*
mkdir -p /var/run/dbus /var/run/pulse /etc/dbus-1/system.d
chown root:root /var/run/pulse

# Allow root to claim PulseAudio DBus names on the system bus
cat <<EOF > /etc/dbus-1/system.d/pulseaudio-root.conf
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="root">
    <allow own="org.pulseaudio.Server"/>
    <allow own="org.PulseAudio1"/>
  </policy>
</busconfig>
EOF

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

# PulseAudio daemon stabilization
cat <<EOF > /etc/pulse/daemon.conf
use-pid-file = no
exit-idle-time = -1
avoid-resampling = yes
flat-volumes = no
default-script-file = /etc/pulse/default.pa
EOF

cat <<EOF > /etc/pulse/client.conf
default-server = unix:/var/run/pulse/pulseaudio.socket
autospawn = no
EOF

# Bind the UNIX socket natively with no auth required for containerized routing
grep -q "auth-anonymous=true" /etc/pulse/default.pa || echo "load-module module-native-protocol-unix auth-anonymous=true socket=/var/run/pulse/pulseaudio.socket" >> /etc/pulse/default.pa

# Disable container-unfriendly modules
sed -i 's/^load-module module-console-kit/#load-module module-console-kit/' /etc/pulse/default.pa || true
sed -i 's/^load-module module-jackdbus-detect/#load-module module-jackdbus-detect/' /etc/pulse/default.pa || true

# Allow hardware to be initialized by the kernel (crucial for slow USB DACs)
echo "Waiting for audio hardware to initialize..."
sleep 5

# Identify the best hardware audio sink automatically (USB > DAC > HDA > Built-in)
BCM2835_CARDS=($(cat /proc/asound/cards | mawk -F '\[|\]:' '/bcm2835/ && NR%2==1 {gsub(/ /, "", $0); print $2}'))
USB_CARDS=($(cat /proc/asound/cards | mawk -F '\[|\]:' '/usb/ && NR%2==1 {gsub(/ /, "", $0); print $2}'))
DAC_CARD=$(cat /proc/asound/cards | mawk -F '\[|\]:' '/dac|DAC|Dac/ && NR%2==1 {gsub(/ /, "", $0); print $2}')
HDA_CARD=$(cat /proc/asound/cards | mawk -F '\[|\]:' '/hda-intel/ && NR%2==1 {gsub(/ /, "", $0); print $2}')

PA_SINK=""
if [[ -n "$USB_CARDS" ]]; then
  PA_SINK="alsa_output.${USB_CARDS[0]}.analog-stereo"
elif [[ -n "$DAC_CARD" ]]; then
  PA_SINK="alsa_output.dac.stereo-fallback"
elif [[ -n "$HDA_CARD" ]]; then
  PA_SINK="alsa_output.hda-intel.analog-stereo"
elif [[ -n "$BCM2835_CARDS" ]]; then
  if [[ "${BCM2835_CARDS[@]}" =~ "bcm2835-alsa" ]]; then
    PA_SINK="alsa_output.bcm2835-alsa.stereo-fallback" # Older kernels
  else
    PA_SINK="alsa_output.bcm2835-jack.stereo-fallback" # Newer kernels
  fi
fi

# Clear old configuration lines if the container gracefully restarted
sed -i '/sink_name=eq/d' /etc/pulse/default.pa
sed -i '/set-default-sink eq/d' /etc/pulse/default.pa
sed -i '/set-sink-volume eq/d' /etc/pulse/default.pa
sed -i "/set-default-sink $PA_SINK/d" /etc/pulse/default.pa

if [[ -n "$PA_SINK" ]]; then
  # Inject the master sink preference directly into pulse system configs
  # Create equalizer targeting the specific hardware sink
  echo "set-default-sink $PA_SINK" >> /etc/pulse/default.pa
  echo "load-module module-ladspa-sink sink_name=eq sink_master=$PA_SINK sink_properties=device.description=\"Equalizer\" plugin=mbeq_1197 label=mbeq control=$SOUND_EQ" >> /etc/pulse/default.pa
else
  # Fallback gracefully if no parsed cards match
  echo "load-module module-ladspa-sink sink_name=eq sink_properties=device.description=\"Equalizer\" plugin=mbeq_1197 label=mbeq control=$SOUND_EQ" >> /etc/pulse/default.pa
fi

# Route everything to EQ and set max hardware volume for unattenuated audio
echo "set-default-sink eq" >> /etc/pulse/default.pa
echo "set-sink-volume eq 65536" >> /etc/pulse/default.pa

# Clean up stale sockets explicitly
rm -f /var/run/pulse/pulseaudio.socket*

echo "Starting configuration for Streamer..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
