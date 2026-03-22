# IoTStreamer

A simple, single-container audio streaming configuration for balenaCloud.

This project turns your Raspberry Pi into a dedicated AirPlay audio receiver. It runs both PulseAudio and Shairport-sync in a single slim container, ensuring low overhead and a highly stable connection.

## Features
- **AirPlay Support**: Stream audio from any Apple device directly to your Raspberry Pi via `shairport-sync`.
- **PulseAudio Backend**: Native routing via ALSA to PulseAudio for broad hardware compatibility.
- **Dynamic Equalizer**: Device-specific hardware EQ profiles powered by LADSPA `mbeq_1197`.
- **High-Quality Audio Auto-Routing**: Automatically detects and prioritizes external USB Soundcards and I2S DACs (like HiFiBerry) over built-in audio.
- **Single Container**: Minimalistic architecture using process supervision for simplicity.

## Getting Started

1. Set up a balenaCloud account and create a new fleet.
2. Add your Raspberry Pi device to the fleet and flash the provided OS image to your SD card.
3. Deploy this code to your fleet using the balenaCLI:

```bash
balena push <fleet-name>
```

4. Once deployed, the device will broadcast itself on your network. Connect to it via any AirPlay-compatible device.

## Configuration

You can configure your streamer by setting the following **Device Variables** in your balenaCloud dashboard:

### Network Broadcast
- **`SOUND_DEVICE_NAME`**: The name of the AirPlay receiver.
  - *Default*: "Raspberry Pi Streamer"

### LADSPA Equalizer
IoTStreamer includes a 15-band LADSPA equalizer using SWH plugins, optimized for high-quality audio. It defaults to a flat `0dB` response, but you can dynamically tune it per-device.

- **`SOUND_EQ`**: A comma-separated list of 15 gain values in dB.
  - *Range*: `-70` to `+30` dB.
  - *Frequencies*: 50Hz, 100Hz, 156Hz, 220Hz, 311Hz, 440Hz, 622Hz, 880Hz, 1.25kHz, 1.75kHz, 2.5kHz, 3.5kHz, 5kHz, 10kHz, 20kHz
  - *Default (Flat)*: `0,0,0,0,0,0,0,0,0,0,0,0,0,0,0`

**Example EQ Profiles:**
- *Bass Heavy:* `12,10,8,6,3,0,-1,-2,-1,0,1,2,3,2,1`
- *Vocal Focus:* `0,0,1,2,3,4,3,2,3,4,3,2,1,0,0`
- *Balanced Aggressive:* `10,8,6,4,1,-1,-2,-2,-1,1,3,5,6,6,4`

### External DACs and High-Quality Audio
The container is equipped with advanced Linux UDev rules to instantly recognize and prioritize high-quality DACs over the default Raspberry Pi headphone jack. 

**USB Soundcards:** 
Simply plug your USB audio interface into the Raspberry Pi. PulseAudio will automatically detect it, prioritize it, and route all AirPlay audio (including the equalizer profile) straight to it. No configuration necessary.

**I2S DACs (e.g. HiFiBerry, Allo Boss, IQAudio):**
1. Navigate to your device settings in balenaCloud.
2. Edit the **Device Configuration** to define the appropriate Device Tree Overlay. For example, add the custom configuration variable `BALENA_HOST_CONFIG_dtoverlay` with the value `hifiberry-dac`.
3. Reboot the device. The kernel will load the DAC, and IoTStreamer will automatically prioritize and route the audio through it.
