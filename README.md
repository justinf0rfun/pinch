# Pinch

Pinch is a macOS 26 menu bar app for placing a built-in phrase into a text
composer without submitting it.

Build the production app and run all tests with one command:

```sh
swift test
```

Run the app with `swift run Pinch`, then press **Option-Space** while an
editable, non-secure text field is focused. Pinch inserts the selected phrase
through macOS Accessibility without submitting it. The old
`Sources/PinchPrototype` code remains only as throwaway interaction evidence
and is not part of the package build.

The permission-gated native text-field smoke test can be run from an
Accessibility-authorized terminal with:

```sh
PINCH_RUN_AX_SMOKE=1 swift test --filter directAccessibilityInsertionSmokeTest
```
