# Contributing to AirPlaneMode

Find a bug? Have a suggestion for a new feature? Notice a mistake in the documentation? Something  *else*?  There are a lot of ways to contribute! Every bit of help is appreciated and welcome!

---

## Ways to contribute

| Type                                  |                                             What it involves |
| :------------------------------------ | -----------------------------------------------------------: |
| 🐛 [Bug report](#bug-report)           |                     Open an Issue describing what went wrong |
| 💡 [Feature request](#feature-request) |                                 Open an Issue with your idea |
| 🔧 [Code](#contributing-code)          |                Fork, branch, change, and open a Pull Request |
| 📝 [Documentation](#documentation)     | Documentation updates, improvements, or just typo correction |

---

## Bug Report

Bug reports are an unfortunate part of software development, but without reports I won't always know there's a problem. If something goes wrong, please [Open an **Issue**](https://github.com/kodermike/airplanemode.koplugin/issues) and include:

- A clear description of what happened vs. what you expected
- Your **KOReader version** (visible in ☰ → Help → About)
- Your **device model** (e.g. Kobo Libra 2, Kindle Paperwhite 5)
- The version of **AirPlaneMode** you are using (visible in ⚙️ → Network → AirPlaneMode → About)
- The steps to reproduce the problem, if you can

If the bug causes a crash, the KOReader log (`crash.log` in the KOReader folder) is very helpful. If you can provide a snippet around the problem, even if it didn't produce a crash there may still be useful information in the log.

---

## Feature Request

If you have a feature request, please  [open an **Issue**](https://github.com/kodermike/airplanemode.koplugin/issues)  describing the feature and why it would be useful. Screenshots or mockups are welcome if they help explain the idea, but not required.

---

## Contributing code

### Setup

**AirPlaneMode** is a KOReader plugin written in Lua. No build system or compilation step is required. The plugin runs directly from the source files.

To test changes:

1. Copy the plugin folder to the `plugins/` directory on your device or the KOReader emulator
2. Restart KOReader to reload the plugin

The [KOReader emulator](https://github.com/koreader/koreader/blob/master/doc/Building.md) is the fastest way to iterate without a physical device.

### Making a change

- **Fork** the [AirPlaneMode repository](https://github.com/kodermike/airplanemode.koplugin.git) (click the Fork button at the top right of the GitHub page). If your change is a new feature, or a bug fix for the `features` branch, be sure to uncheck the option to only copy the `main` branch.
- Create a new branch for your change. If your change is a bug fix, use `fix/` as the prefix. Please branch off of the branch that corresponds to the version you are targeting
	- `main` is for bug fixes that apply to the stable quarterly releases of KOReader
	- `features` is for new features that are not yet ready for a stable release and work against the `nightly` release of KOReader. If it's a new feature, please checkout the `features` branch first, then branch off of it and use `feature/` as the prefix.
```
# If submitting a bug fix for main
git checkout -b fix/my-bug-description
# If submitting a new feature
git checkout features && git checkout -b feature/my-nifty-feature
```
- Make your changes
- **Test** your changes. You can test your changes a few different ways.
  - On a device - copy your changes to `koreader/plugins/airplanemode.koplugin/` on your device, restart KOReader, and verify that everything works still
  - In the emulator - using the instructions found on the [KOReader github page](https://github.com/koreader/koreader/blob/master/doc/Building.md) for setting up the emulator locally. Once compiled, you can put a copy of the `airplanemode.koplugin` directory in `PATH_TO_EMULATOR/plugins/`
- Commit with a  message that describes what changed and why:
```
git commit -m "Fix plugin crashes when on actual airplane"
```
- Push your branch and open a **Pull Request** against the appropriate branch (`main` or `features`)

### Code style

- Follow the style of the surrounding code — indentation, spacing, and naming conventions are consistent throughout the plugin
- Keep functions focused; avoid adding logic to build/render functions that belongs in helpers
- Prefer `local` variables; avoid polluting the module-level scope
- Add a short comment explaining new blocks
- Include type annotations (`@function`, `@param`, `@return`, etc.) if possible. It both helps read your new code and informs LSP helpers when editing.

### File structure

```
airplanemode.koplugin/
├── main.lua                  — plugin entry point
├── flight_config.lua         — generates accessible variables from settings file
├── flight_footer.lua         — generates the footer icon display for reader mode
├── flight_net.lua            — wrapper for network calls
├── flight_plugins.lua        — plugin management for start/stop
├── display/                  — where most ui code should be found
│   ├── flight_menu.lua       — generates the main menu
│   ├── flight_plan_menu.lua  — plugin update menu
└── utils/                    — frequentky reused functions
    ├── flight_helpers.lua    — general filesystem helpers
    ├── flight_plan.lua       — update code
    └── flight_utilities.lua  — utility wrapper for KOReader calls
```

### Pull Request checklist

Before submitting, please verify:

- [ ] The change works on a real device or the KOReader emulator
- [ ] Running `luacheck` reports no errors
- [ ] The commit message clearly describes the change
- [ ] If your change is against the `main` branch, no debug logging or commented-out code is left in. Feature changes can contain debug output until merged into the `main` branch for a stable release.

---

### Documentation

Simple changes to documentation (minor typo corrections, for example) can be submitted in the body of an issue. 

If the documentation suggestions involves new documentation, or significant changes to current documentation, please consider opening a PR using the same steps as feature request and bug reports that involve new PR's. All documentation is in markdown, and submitted changes should also be in markdown as appropriate.

---

Like [KOReader](https://github.com/koreader/koreader)  and it's robust plugin and patch community, all of this is done with the intent to share freely with others. That you are interested in contributing to my efforts means a lot to me. Thank you!
