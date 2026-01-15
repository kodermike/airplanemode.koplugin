# Changelog

## v.1.0.1c (development)

### 🚀 Added

- Issue 35 - Removed extra menu item for plugin management
- Refactored config menu to be a separate sub menu
- Removed message for android devices (no longer relevant)
- Made "disable device management" visible only to users who can manage their hardware
- Issue 36 - Part 1 - Fixed issue with disabling plugins introduced when adding version checking (too much flush'ing)
- Issue 36 - Part 2 - Reworked how disabled plugins get re-enabled. I was just retoring the pre-enable plugins, but that would erase anything added by users. Instead, the plugin now takes the list of currently disabled plugins and just removes the ones defined in airplane mode's disable list.
- Issue 46 - wifi settings that weren't in the original configuration need to be just removed (*except if an emulator*)

## v.1.0.1b (2025.11.25)

### 🔥 Hotfix

- Issue 32 - crash reported on kindle when enabling/disabling outside of reader mode. Confirmed on KLC.

## v.1.0.1 (2025.11.25)

### 🚀 Added

- Added better version management. The plugin will now warn if being run with a config from a newer version; the _meta file has been updated to list the version so that external plugin managers like [UpdatesManager](https://github.com/advokatb/updatesmanager.koplugin) can easily identify whether a local install needs updating; general clean up around how the version is stored and updated within the configs

- Added optional toggling for managing whether the plugin manages the WiFi device. There are scenarios (like Android devices) where we can't, but the lack of management breaks using the plugin for just bulk disabling/enabling WiFi related plugins and options.

- Broke out configuration options into their own sub menu

- Added dynamic "plugin stop" call, supporting the new function call to disable a plugin's external software (like with SSH, which spawns dropbear)

### 🩹 Fixes

- Fixed how reading location is preserved when restarting. Now accurately returns KOReader to the page it restarted on

- Fix for the reader footer patch to not crash when trying to order or save footer preferences ([#17](https://github.com/kodermike/airplanemode.koplugin/issues/17))

## v.1.0.0 (2025.08.16)

### 🚀 Added

- <u>Configuration management</u> (and a configuration to manage!). This includes
  - Minor updates to plugin support, in particular not turning off Calibre and instead just disabling the wireless function. This lets users continue to search using the calibre metadata search even when offline.

  - The ability to silence restart messages when enabling/disabling (#issue13). The intent is to make using gestures more seemless.

  - The option to return to where we left off when restarting (#issue13). **This is experimental.** Not perfect, but the plugin will attempt to return you to your book if you were reading when enabled, or the filemanager if you were in the filemanager. Any other state is ignored and falls back to the default restart settings. This feature depends on the general functionality of koreader to return you to where you left off if you restart and does not always return to the right spot in your book.

  - Introduced internal version tracking so future releases can more easily track upgrade and migration requirements. As a bonus, this should make asking users for which version they installed easier.

  - Changed what (and how to some extent) we store in the airplanemode configuration file. Existing users should be migrated seemlessly the first time they launch koreader with the new version.


### 🩹 Fixes

- Correctly call the ui function to disable SSH if it's running when we start

## v.0.0.4 - QoL update (2025.06.14)

- Remove unnecessary visual of a checkbox

- Added sample user patch for displaying airplane mode status in the reader footer

- If SSH is in our disable list, make sure the process n is stopped. Otherwise it will be running and you can't stop it unless you kill it in terminal. And it blocks USB from launching.

- Info message for feedback when a gesture is used

- May have finally locked down networking on kindles. Tests on paperwhite are now consistantly up

## v0.0.3 (2025.05.26)

### 🚀 Added

- Gesture support

### 🩹 Fixes

- Finally figured out enable/disble wifi so it works on different devices correctly. Tested on Clara and Kindle, plugin settings reverted correctly, wifi reconnected correctly, and wireless settings are not lost

- Changed how we set and reset the disabled plugins list in the main settings.reader.lua. We were not always re-enabling plugins if they appeared in our own airplane module list.

- Fixed how the wifi settings are re-enabled when exiting

- Restore wifi state to the same state it was when AirPlane started - off or on

- Fixed deleting all temporary plugin disables before restoring

## v0.0.2 (2025.05.22)

### 🚀 Added

- No additions today.

### 🩹 Fixes

- Replaced how we reference files from `rootpath` to the function for
  `DataStorage:getDataDir` - I suspect this was causing some of the issues on
  non-kobo devices (ie, worked on kobo does not mean it works everywhere)
- Removed a block from the original release that was causing the list of files
  to be considered part of AirPlane Mode to include anything already disabled
  - which also meant when exiting AirPlane Mode, it was erasing those entries
    from the settings files

- Removed a block that was setting a variable, replacing the value, resetting it, but never actually _using_ it

## v0.0.1 (2025.05.21)

### 🚀 Added

- Clicking AirPlane Mode now opens a menu where you can choose between
  enable/disabe and editing which plugins are included as disabled

- Generate a default file of plugins on first use - this is only generated if
  there is no list file

- Added menu of all installed plugins on your device with the option of adding
  any of them to the disabe list when AirPlane mode is enabled

- Added paperplane icons to indicate status

- Documentation updated!

### 🩹 Fixes

- cleaned up all of the commented code and debug statements :-)

## v0.0.1-alpha (2025.05.06)

- Initial testing release

### 🚀 Added

- Everything

### 🩹 Fixes

- Existential nihilism
