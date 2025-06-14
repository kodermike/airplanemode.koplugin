# AirPlane Mode for KOReader

This plugin is intended to give you the ability to quickly put your koreader into AirPlane mode, disabling any netwoked plugins, as well as your wireless device. It will also switch your wireless device to force prompts while in AirPlane. Exiting AirPlane mode will re-enable your previous plugins and re-set your WiFi settings to pre-AirPlane mode settings.

---

## Installation

1. Connect your device to USB
1. Copy the `airplanemode.koplugin` directory to `plugins/` or unpack a release file in your plugins directory. On Kobo, this would be in `.adds/koreader/plugins`, on kindle's it is usually in `/mnt/us/koreader/plugins` (if you use a different architecture, let me know and I'll add it :) 
1. Disconnect USB

## Usage

### Enabling

In the Nework tab, tap or click the menu for `AirPlane Mode`. 

![Screenshot of the Network tab with AirPlane Mode installed](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_network_menu.png>)

The `AirPlane Mode` menu is very simple - you can toggle `AirPlane Mode` and control which plugins will be disabled while it's running.

![Screenshot of the AirPlane Mode menu when disabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_disabled.png>)

Tapping on `Enable` will start `AirPlane Mode` and prompt to restart your device. This is necessary for the changes we've made to running plugins to take effect.

![Screenshot of the AirPlane Mode menu when disabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_starting.png>)

### Disabliing

Turning AirPlane Mode off is simple. Return to the `AirPlane Menu` in `Network` and tap the `Disable` the button. We will need to restart again since we are re-enabling plugins that were disabled while offline.

![Screenshot of the AirPlane Mode menu when disabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_stopping.png>)

## Plugin Management while in AirPlane Mode

Selecting `AirPlane Mode Plugin Manager` will let you chose which plugins will be disabled when in `AirPort Mode`.

![Screenshot of the AirPlane Mode menu when disabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_disabled.png>)

By default, AirPlane Mode will disable the plugins 
* `Calibre`
* `HTTP Inspector`
* `News Downloader`
* `OPDS`
* `Progress Sync`
* `SSH`
* `Time Sync`
* `Wallabag`

These are all plugins that come pre-installed and enabled in most KOReader bundles. In the `AirPlane Mode Plugin Manager` you will have the option to choose other plugins, as well as let some of the default disables be re-enabled. When in this menu, you will not be able to disable plugins if they are already disabled in your reader.

![Screenshot of the AirPlane Mode menu when disabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_module_select.png>)

If you attempt to change which modules `AirPlane Mode` has diabled in the Module menu while running `AirPlane Mode`, you will receive an error message.

![Screenshot of the AirPlane Mode Plugin Manager if AirPlane is already running](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/airplane_running_no_mod.png>)

When you exit `AirPlane Mode`, any plugins that were not disabled before you started will be reactivated by the restart.

## Gestures

AirPlane Mode supports three gesture actions - enable, disable, and toggle.

## Extras!

In the `misc` directory, you will find a userpatch to add a notification icon in the readerfooter, for those of us that need that reminder while reading that we are in airplane mode. To use, make sure you have (or create) a patches directory in your koreader root, then copy the `2-airplane-footer.lua` to that directory.

---

## IF YOU TESTED THE FIRST ALPHA

For this iteration, I changed how we manage the plugins to disable/enable when switching modes. If your device is currently in `AirPlane Mode`, please exit `AirPlane Mode` before upgrading.

## Find a bug?

Please open an issue in GitHub so we can start looking at what isn't working right.


###### Updated 2025.06.14
