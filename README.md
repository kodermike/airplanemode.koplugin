# AirPlane Mode for KOReader

<div align="center">

![GitHub release (latest by date)](https://img.shields.io/github/v/release/kodermike/airplanemode.koplugin?style=for-the-badge&color=orange)
![GitHub all releases](https://img.shields.io/github/downloads/kodermike/airplanemode.koplugin/total?style=for-the-badge&color=yellow)
![GitHub](https://img.shields.io/github/license/kodermike/airplanemode.koplugin?style=for-the-badge&color=blue)
![Platform](https://img.shields.io/badge/Platform-KOReader-success?style=for-the-badge&logo=koreader)

</div>

**AirPlane Mode** is a simple plugin to let you enable/disable anything networking related in KOReader with a single tap. Configuration options let you manage what is disabled, and how **AirPlane Mode** behaves when invoked. 

---

## 📥 Installation

### Installing with a release file

1. Download the latest release from [Releases](https://github.com/kodermike/airplanemode.koplugin/releases)
1. Connect your device with USB
1. You can either:
    1. Unpack the release file locally, then copy the `airplanemode.koplugin` directory to `plugins/` or
    1. unpack a release file in your plugins directory. For example,
      - On Kobo, this would be in `.adds/koreader/plugins`
      - On Kindle's it is in `/mnt/us/koreader/plugins`
1. Disconnect your device. You should be all set!

### Alternate installation for kobo's    

1. On the [Releases](https://github.com/kodermike/airplanemode.koplugin/releases), download `KoboRoot.tgz`.
1. Connect your device with USB
1. Copy the the `KoboRoot.tgz` file to the `.kobo` directory on your mounted kobo.
1. Disconnect USB, then reboot your reader. In order for the `KoboRoot.tgz` file to be unpacked, you will need to exit KOReader completely and restart your Kobo so that the native Kobo manager can unpack the `KoboRoot.tgz` file
1. Once your Kobo is back up, start KOReader again

## Usage

![AirPlane Mode icon when disabled](<.github/assets/disabled.jpg>)

In the Network tab, tap or click the menu for `AirPlane Mode`. If the paper airplane is dark, AirPlane Mode is currently running.

![AirPlane Mode main menu](<.github/assets/menu.png>)

From the top menu, you can:

* enable or disable `AirPlane Mode`.
* edit the list of plugins that are disabled when running `AirPlane Mode`. By default, the following core plugins that rely on networking are disabled.

  * `Calibre` [^1]
  * `HTTP Inspector`
  * `News Downloader`
  * `OPDS`
  * `Progress Sync`
  * `SSH`
  * `Time Sync`
  * `Wallabag`

[^1]: Calibre change: Previous versions of this plugin completely disabled the Calibre plugin, which had the unfortunate side effect of disabling calibre metadata searching. The default behavior now is to only disable the wireless function for Calibre

| ![AirPlane Mode plugin manager](<.github/assets/menu1.jpg>)
| ------ |

Select any additional plugins you do not want running when AirPlane Mode is enabled. __This selection does not affect plugins outside of AirPlane Mode.__ Selecting a plugin to be disabled from this menu only affects KOReader while AirPlane Mode is running.

* Configuration Menu

![AirPlane Mode Configuration Menu](<.github/assets/advanced_config.png>)

New with 1.0.1, the Configuration Menu lets you manage the following additional settings:
* **Silence the restart message** - enabling this feature will mute restart notifications when enabling and disabling AirPlane mode. Other KOReader dialogs will still appear, such as `Scanning for networks`, but you will not be prompted to confirm a restart
* **Restore session after restart** - this feature is highly experimental. If enabled, when KOReader restarts the plugin will attempt to bring you back to where you left off (filebrowser or last open document), regardless of what your default setting is for restarts.
* **Disable managing WiFi** - this feature is a side effect of work done for users on devices that don't support KOReader managing wifi, but that still wanted the advantage of being to enable and disable network related plugins. For those users, this feature is automatically enabled; for everyone else, sleecting this will disable the network management portion of the plugin. Instead, the plugin will only disable and enable all relevant plugins in one action.

![AirPlane Mode icon when enabled](<.github/assets/enabled.jpg>)

## Gestures

`AirPlane Mode` supports three gesture actions - enable, disable, and toggle. These can be configured in the regular gesture menu.

## Extras

In the `misc` directory, you will find a userpatch to add a notification icon in the readerfooter, for those of us that need that reminder while reading that we are in `AirPlane Mode`. To use, make sure you have (or create) a patches directory in your koreader root, then copy the `2-airplane-footer.lua` to that directory.

---

## Find a bug?

Please open an issue in GitHub so we can start looking at what isn't working right.



###### Updated 2025.11.25
