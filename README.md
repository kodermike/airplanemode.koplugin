# AirPlaneMode for KOReader

<div align="center">

![GitHub release (latest by date)](https://img.shields.io/github/v/release/kodermike/airplanemode.koplugin?style=for-the-badge&color=orange)
![GitHub all releases](https://img.shields.io/github/downloads/kodermike/airplanemode.koplugin/total?style=for-the-badge&color=yellow)
![GitHub](https://img.shields.io/github/license/kodermike/airplanemode.koplugin?style=for-the-badge&color=blue)
![Platform](https://img.shields.io/badge/Platform-KOReader-success?style=for-the-badge&logo=koreader)

</div>

**AirPlaneMode** is a [KOReader](https://github.com/koreader/koreader.git) plugin that lets you enable/disable networking and selected plugins in one action. The plugin focuses on safely disabling identified plugins while preserving user plugin preferences when disabling.

---

## 🚀 What it does

- Enabling **AirPlaneMode** will:
  - Back up the current KOReader settings file
  - Disables a configurable set of plugins
  - Disables Wi‑Fi, and changes default Network settings to disable automatic activation
  - If the Calibre plugin is enabled, adjusts Calibre's wireless-only settings to off while leaving the plugin search functions enabled
- Disabling **AirPlaneMode** will:
  - restore previous settings from the backup
  - re-enables plugins that were disabled for **AirPlaneMode**

  - Return Wi‑Fi settings to their previous configuration

_On devices where network hardware cannot be managed, Wi‑Fi actions are skipped._

---

## 📥 Installation

#### Installing using a release archive file

1. Download the latest release from [Releases](https://github.com/kodermike/airplanemode.koplugin/releases)
1. Connect your device with USB
1. You can either:
   1. Unpack the release file locally, then copy the `airplanemode.koplugin` directory to `plugins/` or
   1. unpack a release file in your plugins directory. For example,
   - On Kobo, this would be in `.adds/koreader/plugins`
   - On Kindle's it is in `/mnt/us/koreader/plugins`
1. Disconnect your device and restart KOReader. You should be all set!

#### Alternate installation for Kobo's

1. On the [Releases](https://github.com/kodermike/airplanemode.koplugin/releases) page, download `KoboRoot.tgz`.
1. Connect your device with USB
1. Copy the the `KoboRoot.tgz` file to the `.kobo` directory on your mounted kobo.
1. Disconnect USB, then reboot your reader. In order for the `KoboRoot.tgz` file to be unpacked, you will need to exit KOReader completely and restart your Kobo so that the native Kobo manager can unpack the `KoboRoot.tgz` file
1. Once your Kobo is back up, start KOReader again

#### For users of AirPlaneMode >=2.0

- In the configuration menu, you can elect to update **AirPlaneMode** directly from the plugin in the Advance Settings menu.

## Usage

![AirPlane Mode icon when disabled](.github/assets/disabled.jpg)
**AirPlaneMode** registers a menu entry in the Network menu where you can:

![AirPlaneMode-menu](.github/assets/AirPlaneMode-menu.png)

- Enable / Disable **AirPlaneMode**
- Manage which builtin and user plugins should be disabled when **AirPlaneMode** is active
- Enable silent restarts (assumes confirmation) so that you aren't prompted to restart
- Toggle **AirPlaneMode** visibility in the reader footer. This option also requires `External Content` in the status bar UI to be included.
- Enable the option to resume where you left off if possible when restarting with **AirPlaneMode**. This option temporarily overrides preferences to resume where you left off when toggling **AirPlaneMode**.
- For applicable devices, disable managing Wi-Fi so that **AirPlaneMode** only manages Plugin settings when enabled
- Open the **AirPlaneMode** Advanced Settings menu

The Advanced Settings menu offers the following

![AirPlaneMode-Advanced](.github/assets/AirPlaneMode-Advanced.png)

- Detailed information about your current setup. This information is especially useful when filing an issue
- Enable/Disable `Developer Mode`. Developer mode enables features that are still being developed but are not yet ready for general use. At present, this includes:
  - Update Management
  - Debug logging

## Gesture support

Gestures (Device -> Gestures) can be configured to call **AirPlaneMode** actions; the Plugin registers three dispatcher actions you can bind to gestures or hotkeys:

- `airplanemode_enable` — enable AirPlaneMode
- `airplanemode_disable` — disable AirPlaneMode
- `airplanemode_toggle` — toggle AirPlaneMode on/off

## Default disabled plugins

- On first run **AirPlaneMode** populates a default list of plugins to disable while active. The defaults can be overwritten, changed, etc. The initial plugins are:
  - `newsdownloader`
  - `wallabag`
  - `kosync`
  - `opds`
  - `SSH`
  - `timesync`
  - `httpinspector`
  - `calibre` (wireless component only)

Note: **AirPlaneMode's** Plugin Manager only disables plugins in KOReader while **AirPlaneMode** is active — it does not edit KOReader plugin settings directly.

![AirPlane Mode icon when enabled](.github/assets/enabled.jpg)

---

## Contributing

Find a bug 🐛? Want to contribute 🤝? Please see [CONTRIBUTING](CONTRIBUTING.md) for more information.

## 🔧 Developer Notes

- **AirPlaneMode** supports the `stopPlugin` dispatcher action to stop **AirPlaneMode** from another service or plugin while it is active.
- **AirPlaneMode** also supports the `deletePluginSettings` dispatcher action to delete all AirPlaneMode settings and reset the installation to a clean slate.
- The `feature` branch is suitable for testing against nightly KOReader builds. The `main` branch is intended to work with stable releases.
- For more detailed information on contributing, please see [CONTRIBUTING.md](CONTRIBUTING.md).

###### Updated 2026.06.20
