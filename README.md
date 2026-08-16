# Nimbus

A native macOS weather app: cinematic weather scenes, detailed [Open-Meteo](https://open-meteo.com/) forecasts, a Pro inspector, menu bar extra, and desktop widgets.

**Languages:** [English](README.md) · [Español](docs/readme/README.es.md) · [Français](docs/readme/README.fr.md) · [Deutsch](docs/readme/README.de.md) · [Italiano](docs/readme/README.it.md) · [Português (Brasil)](docs/readme/README.pt-BR.md) · [Nederlands](docs/readme/README.nl.md) · [العربية](docs/readme/README.ar.md) · [日本語](docs/readme/README.ja.md) · [한국어](docs/readme/README.ko.md) · [简体中文](docs/readme/README.zh-Hans.md) · [繁體中文](docs/readme/README.zh-Hant.md)

## Open

```
open Nimbus.xcodeproj
```

Or run the packaged app from a GitHub Release.

Requires macOS 15+ and Xcode 16 / 26 to build from source.

## First launch

The sidebar starts with **My Location** plus popular cities. Search any other city and tap **Add**. Language and units follow the system until you override them in Settings.

- `⌘I` inspector
- `⌘R` refresh
- `⌘[` / `⌘]` previous / next city
- `⌘,` settings (Done closes the sheet)
- Click a condition card for an overlay detail (not an in-grid accordion)

Motion follows **Reduce Motion**. You can force animation on or off in Settings.

## Data

Forecasts, air quality, geocoding, and ensemble mean come from Open-Meteo. Non-commercial public API, no key. **My Location** uses approximate (about 1 km) coordinates only — not precise GPS — and that coarsened position is what is stored and sent to Open-Meteo.

## Tests

```
cd Nimbus && swift test
```
