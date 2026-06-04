# Esports360

Native iOS 17+ SwiftUI app for Arabic-first esports scores, Saudi esports coverage, and live match tracking.

## Current MVP Scope

- Dark-first SwiftUI shell with Arabic RTL as the default language.
- MVVM + Repository folder structure.
- Design system colors, typography helpers, and reusable score/live components.
- PandaScore REST client using async/await and Codable DTO mapping.
- Native `URLSessionWebSocketTask` live-score stream manager.
- Home feed backed by mock data by default, with optional PandaScore token wiring in Settings.
- Live Home updates wired through the WebSocket manager when a PandaScore token is available.
- Local match-start reminders using `UNUserNotificationCenter`.
- Tournament bracket screen with pinch-to-zoom, winner highlights, progression animation, and sortable group standings.
- Team and player profile screens with roster cards, recent results, form, and Swift Charts stats.
- Native image pipeline using `AsyncImage`, a configured shared `URLCache`, local asset placeholders, PandaScore image URLs, Data Dragon champion URLs, and Valorant agent CDN URLs.
- Deep-link routing for match, team, tournament, and player URLs.
- SwiftData cache entity scaffold for 24h match TTL / 6h stats TTL expansion.
- Unit tests for repository mock data, PandaScore DTO mapping, live score updates, and deep-link parsing.

## Running

Open `Esports360.xcodeproj`, choose an iOS Simulator, and run the `Esports360` scheme.

The app uses mock data until a PandaScore token is added in Settings. For production, PandaScore requests should be proxied through a backend so the private API token is not embedded in the app binary.

Universal Links are configured in-app for `applinks:esports360.app`. Production launch still needs the matching Apple App Site Association file hosted on the final domain and the real Apple Developer team selected for signing.

## Verified Locally

```sh
xcodebuild -project Esports360.xcodeproj -scheme Esports360 -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build
xcodebuild -project Esports360.xcodeproj -scheme Esports360 -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```
