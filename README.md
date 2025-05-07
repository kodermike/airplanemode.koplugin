# AirPlane Mode for KOReader

This plugin is intended to give you the ability to quickly put your koreader into AirPlane mode, disabling any netwoked plugins, as well as your wireless device. It will also switch your wireless device to force prompts while in AirPlane. Exiting AirPlane mode will re-enable your previous plugins and re-set your WiFi settings to pre-AirPlane mode settings.

## Installation

1. Connect your device to USB
1. Copy the `airplanemode.koplugin` directory to `.adds/koreader/plugins/` or unpack a release file in your plugins directory
1. Disconnect USB

## Usage

In the Nework tab, check the checkbox for `AirPlane Mode`. Koreader will restart when enabling and disabling AirPlane mode.

![Screenshot of the Network tab with AirPlane Mode installed](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_mode_menu.png>)

## Missing plugin or bug?

If I missed a network using plugin, just open an issue and I'll add it! And of course, if you find a bug, let me know.

## Known Caveat

Currently, AirPlane mode attemtpts to re-enable yoru WiFi device when exiting. I may change this behavior in the future and let your previous setting handle whether to reconnect.
