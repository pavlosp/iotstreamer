# Raspberry Pi Audio Streamer

A simple, single-container Airplay audio streaming configuration for balenaCloud.

This project turns your Raspberry Pi into a dedicated AirPlay audio receiver. It runs both PulseAudio and Shairport-sync in a single slim container, ensuring low overhead and a highly stable connection.

## Features
- **AirPlay Support**: Stream audio from any Apple device directly to your Raspberry Pi via `shairport-sync`.
- **PulseAudio Backend**: Native routing via ALSA to PulseAudio for broad hardware compatibility.
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

You can configure the broadcast name of your AirPlay receiver by setting the following Device Variable in your balenaCloud dashboard:

- `SOUND_DEVICE_NAME`: The name of the AirPlay receiver (Default: "Raspberry Pi Streamer")
