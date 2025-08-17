
# AirPlane Mode for KOReader

This plugin is intended to give you the ability to quickly put your koreader into `AirPlane Mode`, disabling any netwoked plugins, as well as your wireless device. It will also switch your wireless device to force prompts while in `AirPlane Mode`. Exiting `AirPlane Mode` will re-enable your previous plugins and re-set your WiFi settings to pre-AirPlane Mode settings.

---

## Installation

1. Connect your device to USB
1. Either:
    1. Copy the `airplanemode.koplugin` directory to `plugins/` or
    1. unpack a release file in your plugins directory. On Kobo, this would be in `.adds/koreader/plugins`, on kindle's it is usually in `/mnt/us/koreader/plugins` (if you use a different architecture, let me know and I'll add it :) or
    1. If you have a kobo running koreader, you can place the KoboRoot.tgz file in your `.kobo` directory and reboot.
1. Disconnect USB

## Usage

![AirPlane Mode icon when disabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/disabled.jpg>)

In the Nework tab, tap or click the menu for `AirPlane Mode`. If the paper airplane is dark, AirPlane Mode is currently running.

![AirPlane Mode main menu](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/menu.jpg>)

From the top menu, you can:

* enable or disable `AirPlane Mode`.
* edit the list of plugins that are disabled when running `AirPlane Mode`. By default, core plugins that rely on networking are disabled.

  * `Calibre` [^1]
  * `HTTP Inspector`
  * `News Downloader`
  * `OPDS`
  * `Progress Sync`
  * `SSH`
  * `Time Sync`
  * `Wallabag`

| ![AirPlane Mode plugin manager](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/menu1.jpg>) | ![AirPlane Mode plugin manager](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/menu2.jpg>) | ![AirPlane Mode plugin manager](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/menu3.jpg>) |
| ------ | ------ | ------ |

Select any additional plugins you do not want running when AirPlane Mode is enabled. __This selection does not affect plugins outside of AirPlane Mode.__

![Additional settings now available](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/extra-settings.jpg>)

* Control whether you are prompted when `AirPlane Mode` needs to restart your device. Restarts are required when enabling/disabling for changes to plugins to take affect.
* Enable an experimental feature to return you to where you left off when koreader was restarted by `AirPlane Mode`. If you are reading, this will return you to the last page you were on after `AirPlane Mode` restarts (even if filemanager is your default on reboots); if you are in filebrowser, you will return to filebrowser, even if "last page read" is your default. "Last page" is as accurate as koreader last saved your position and is not managed by `AirPlane Mode` directly.

![AirPlane Mode icon when enabled](<https://raw.githubusercontent.com/kodermike/kodermike.github.io/refs/heads/master/images/enabled.jpg>)

## Gestures

`AirPlane Mode` supports three gesture actions - enable, disable, and toggle.

## Extras

In the `misc` directory, you will find a userpatch to add a notification icon in the readerfooter, for those of us that need that reminder while reading that we are in `AirPlane Mode`. To use, make sure you have (or create) a patches directory in your koreader root, then copy the `2-airplane-footer.lua` to that directory.

---

## Find a bug?

Please open an issue in GitHub so we can start looking at what isn't working right.

[^1]: Calibre change: Previous versions of this plugin completely disabled the Calibre plugin, which had the unfortunate side effect of disabling calibre metadata searching. The default behavior now is to only disable the wireless function for Calibre

###### Updated 2025.08.16
