# Changelog

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
