# World Clock App

A native macOS world clock app built with SwiftUI. Displays multiple time zones as analog-style clock widgets with integrated calendar events for your daily meetings.

![macOS](https://img.shields.io/badge/macOS-26.2+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-black?style=flat-square&logo=swift)

## Features

### World Clocks
- **Multiple time zones** — Add and remove clocks for 22+ preset cities across the globe
- **Analog-style display** — Circular clock faces with 60 tick marks, updated every second
- **Time offset** — Shows the hour difference from your local time zone
- **Dark & Light themes** — Toggle theme per clock via context menu
- **Resizable** — Pinch-to-zoom or use +/- buttons (0.4x–2.5x scale)
- **Hover controls** — Delete and resize buttons appear on hover

### Calendar Integration
- **Today's meetings** — Displays events fetched from your calendars via EventKit
- **Calendar picker** — Filter events by calendar source (iCloud, Google, etc.)
- **Compact & expanded views** — Horizontal scrollable cards or a detailed vertical list
- **Resizable panel** — Drag handle to adjust the calendar panel height (60–300px)
- **Active meeting indicator** — Green dot highlights ongoing meetings
- **Event details** — Time range, location, and calendar color coding

### Supported Cities

| Region | Cities |
|--------|--------|
| **Europe** | Istanbul, London, Paris, Berlin, Moscow |
| **Americas** | New York, San Francisco, Chicago, Denver, Honolulu, São Paulo, Mexico City |
| **Asia** | Dubai, Mumbai, Bangkok, Hong Kong, Singapore, Tokyo, Seoul, Jakarta |
| **Oceania** | Sydney, Auckland |

Custom timezone identifiers can also be used programmatically.

## Screenshots

<!-- Add screenshots here -->

## Requirements

- macOS 26.2 or later
- Xcode 26.2 or later

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/akingundogdu/world-clock-mac-app.git
   ```
2. Open the project in Xcode:
   ```bash
   cd world-clock-mac-app
   open world-clock-app.xcodeproj
   ```
3. Build and run (`⌘R`).

On first launch the app will request **calendar access** to display your meetings. This is optional — the clocks work without it.

## Project Structure

```
world-clock-app/
├── world_clock_appApp.swift       # App entry point & window configuration
├── ContentView.swift              # Main container, clock layout & state
├── ClockWidgetView.swift          # Analog clock widget component
├── CalendarEventsView.swift       # Calendar integration & event display
├── world_clock_app.entitlements   # Sandbox & permission config
└── Assets.xcassets/               # App icon & color assets
```

## Architecture

- **Pure SwiftUI** — No external dependencies; built entirely with Apple frameworks
- **EventKit** — Calendar access and event fetching
- **ServiceManagement** — Optional launch-at-login support
- **Combine** — Timer-driven updates (1s for clocks, 30s for calendar)

State is managed with `@State`, `@StateObject`, and `@Published` for reactive UI updates.

## Permissions

| Permission | Reason |
|------------|--------|
| Calendar (Full Access) | Display today's meetings below your world clocks |
| User-selected files (Read) | App sandbox requirement |
| App Sandbox | Enabled for security |

## License

This project is provided as-is for personal use.
