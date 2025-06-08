# Changelog

## v.0.0.4 - QoL update

* Remove unnecessary visual of a checkbox

* Added sample user patch for displaying airplane mode status in the reader footer

### TODO

* user patch currently crashes if you tap on `Status Bar Presets`

* Need to work out firast time launch with patch - seemed to take a few restart before it appeared in the menu options

* Can SSH (the process) be turned off when we enter apm? I've found that even though the plugin is disabled, the process is still running and causea problems with USBM. Or could look at submitting that as a bug report...



## v0.0.3  (2025.05.26) - UNRELEASED CURRENTLY


### 🚀 Added

* Gesture support

### 🩹 Fixes

* Finally figured out enable/disble wifi so it works on different devices correctly. Tested on Clara and Kindle, plugin settings reverted correctly, wifi reconnected correctly, and wireless settings are not lost

* Changed how we set and reset the disabled plugins list in the main settings.reader.lua. We were not always re-enabling plugins if they appeared in our own airplane module list.

* Fixed how the wifi settings are re-enabled when exiting

* Restore wifi state to the same state it was when AirPlane started - off or on

* Fixed deleting all temporary plugin disables before restoring


## v0.0.2  (2025.05.22)

### 🚀 Added

* No additions today.

### 🩹 Fixes

* Replaced how we reference files from `rootpath` to the function for
  `DataStorage:getDataDir` - I suspect this was causing some of the issues on
  non-kobo devices (ie, worked on kobo does not mean it works everywhere)
  
* Removed a block from the original release that was causing the list of files
  to be considered part of AirPlane Mode to include anything already disabled
  - which also meant when exiting AirPlane Mode, it was erasing those entries
  from the settings files

* Removed a block that was setting a variable, replacing the value, resetting it, but never actually *using* it

## v0.0.1 (2025.05.21)

### 🚀 Added

* Clicking AirPlane Mode now opens a menu where you can choose between
  enable/disabe and editing which plugins are included as disabled

* Generate a default file of plugins on first use - this is only generated if 
there is no list file

* Added menu of all installed plugins on your device with the option of adding
  any of them to the disabe list when AirPlane mode is enabled

* Added paperplane icons to indicate status

* Documentation updated!

### 🩹 Fixes

* cleaned up all of the commented code and debug statements :-)

## v0.0.1-alpha (2025.05.06)

* Initial testing release

### 🚀 Added

* Everything

### 🩹 Fixes

* Existential nihilism
