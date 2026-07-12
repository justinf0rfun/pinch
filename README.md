# Pinch

Pinch is a macOS 26 menu bar app for placing a built-in phrase into a text
composer without submitting it.

The static English product site lives in `site/`. Preview it with:

```sh
python3 -m http.server 8000 --directory site
```

Build the production app and run all tests with one command:

```sh
swift test
```

Run the app with `swift run Pinch`, then press **Option-Space** while the
ChatGPT composer is focused. Pinch inserts the selected phrase without
submitting it. The old
`Sources/PinchPrototype` code remains only as throwaway interaction evidence
and is not part of the package build.

The permission-gated ChatGPT smoke test can be run from an
Accessibility-authorized shell with:

```sh
PINCH_RUN_CHATGPT_AX_SMOKE=1 swift test --filter chatGPTAccessibilityInsertionSmokeTest
```
