Testing framework for AirPlaneMode plugin

This repository contains a lightweight testing framework under `tests/` that lets you run unit-style specs for the plugin without a full KOReader checkout. The tests are written to work with the `busted` test runner.

Files added

- `tests/spec_helper.lua` — sets up a minimal KOReader-like environment (mocks for UIManager, Dispatcher, Device, NetworkMgr, utilities, etc.) and provides helpers.
- `tests/main_spec.lua` — example specs for the plugin (loading, dispatcher registration, settings initialization).
- `tests/run_tests.sh` — convenience script to run the tests with `busted`.

Prerequisites

- Lua 5.1/5.2/5.3 compatible runtime.
- busted (install with `luarocks install busted`).

Running tests

From the plugin root directory run:

```tests/run_tests.sh#L1-20
(./tests/run_tests.sh)
```

Notes and how to extend

- By default tests use the mocks in `spec_helper.lua`. If you want to run the plugin code against a full KOReader checkout, set the `KOREADER_PATH` environment variable and modify `spec_helper.lua` to `require` real KOReader modules from that path instead of providing mocks.

- Add more specs under `tests/` using `busted`'s `describe/it` style. Use `require("tests/spec_helper")` at the top of your spec to get the mocked environment and helpers.

- The mocks in `spec_helper.lua` are intentionally minimal. When a real KOReader module is required by the plugin and you want to exercise its behavior, replace the mock with a more complete stub that implements just the required methods for the test.

- If you prefer not to use `busted`, you can run Lua directly. The current test suite assumes `busted` APIs such as `describe` and `it`.
