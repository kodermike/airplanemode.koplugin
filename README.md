# AirPlane Mode for KOReader

This plugin is intended to give you the ability to quickly put your koreader into AirPlane mode, disabling any netwoked plugins, as well as your wireless device. It will also switch your wireless device to force prompts while in AirPlane. Exiting AirPlane mode will re-enable your previous plugins and re-set your WiFi settings to pre-AirPlane mode settings.

--

## IF YOU TESTED THE ALPHA

For this iteration, I changed how we manage the plugins to disable/enable when switching modes. If your device is currently in `AirPlane Mode`, please exit `AirPlane Mode` before upgrading.

--

## Installation

1. Connect your device to USB
1. Copy the `airplanemode.koplugin` directory to `.adds/koreader/plugins/` or unpack a release file in your plugins directory
1. Disconnect USB

## Usage

In the Nework tab, enter the menu for `AirPlane Mode`. You can choose to enable/disable AirPlane Mode from here.

<!-- Update Screenshot -->
![Screenshot of the Network tab with AirPlane Mode installed](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_mode_menu.png>)

When not enabled, you can also go through the list of your installed plugins and choose which ones to disable when in `AirPlane Mode`.

<!-- ADD SCREENSHOT -->

## Find a bug?

Please open an issue in GitHub so we can start looking at what isn't working right.
