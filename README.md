# MagicWand — LG webOS TV Remote (SwiftUI)

A SwiftUI remote-control app for LG webOS televisions (built and tested against the
**LG UP7500PVG**). It connects over your normal Wi-Fi (LAN) using the webOS **SSAP**
WebSocket protocol for control, and uses **AirPlay** for the media-casting tab.

- **Platform:** iOS 26+ (the current stable release as of June 2026)
- **Language / UI:** Swift 6, SwiftUI (latest stable APIs — `@Observable`, `NavigationStack`, `PhotosPicker`)
- **Storage:** local `UserDefaults` (no backend), holding the list of previously-paired
  TVs and their webOS client-keys for silent reconnects.

## Screens

| Tab | Screen | Notes |
|-----|--------|-------|
| Remote | `RemoteView` | Power / browser / input, channel & volume rockers, settings/search/home/mute, number pad, on-screen keyboard relay, central D-pad/trackpad, back/exit, colour keys, **Apps**, play/pause |
| Cast | `CastingView` | "Media casting" hero + `PhotosPicker`; routes to the TV via the AirPlay picker |
| Library | `LibraryView` | **Replaces the reference app's Settings tab** — lists every TV you've connected to, tap to reconnect, swipe to remove, `+` to add by IP |

**Apps** list (`AppsView`) mirrors the reference "My Apps" screen and launches the real
webOS launch-points (Netflix, YouTube, Disney+, Prime Video, …).

### Connection / onboarding flow
1. **Setting up** (`SearchingView`) — SSDP discovery scan.
2. **Connect your TV** (`SelectTVView`) — pick from discovered TVs; Refresh; or
   **"I don't see the device"** → manual IP entry.
3. **Let's pair your phone with the TV** (`PairingView`) — enter the PIN webOS shows on
   the TV; we send it via `ssap://pairing/setPin` and persist the returned client-key.

## Building

Requires **Xcode 26** (the project uses a file-system–synchronized group, objectVersion 77).

```bash
open MagicWand.xcodeproj
```

Select the `MagicWand` scheme and run on a device on the **same Wi-Fi network** as the TV.
(The Simulator can build/run the UI but can't reach a real TV reliably; use a device for
end-to-end control.)

## Required capabilities & Info.plist keys

Already configured in `MagicWand/Info.plist`:

- `NSLocalNetworkUsageDescription` + `NSBonjourServices` — iOS 14+ local-network privacy
  prompt (required to talk to the TV on the LAN).
- `NSAppTransportSecurity → NSAllowsLocalNetworking` — allows the plain `ws://<tv>:3000`
  control socket.
- `NSPhotoLibraryUsageDescription` — for the casting picker.

**You must add manually in Signing & Capabilities** (these need your team / Apple approval):

- **Multicast Networking** entitlement
  (`com.apple.developer.networking.multicast`) — needed for SSDP auto-discovery. Until
  it's granted, use the **"I don't see the device"** manual-IP path, which needs no
  special entitlement. Find the TV's IP under *Settings › Network* on the TV.
- **Access Wi-Fi Information** is *not* required.

## webOS protocol notes

- Control socket: `ws://<tv>:3000` (plain) or `wss://<tv>:3001` (TLS, self-signed cert is
  trusted by `SSAPClient`'s `URLSessionDelegate`).
- Registration sends a manifest with `pairingType: "PIN"`; on reconnect the stored
  `client-key` is sent instead so the TV doesn't prompt again.
- Hardware buttons (D-pad, colour keys, media) go over the secondary **pointer input
  socket** obtained from `ssap://com.webos.service.networkinput/getPointerInputSocket`.

## Project layout

```
MagicWand/
├── MagicWandApp.swift          App entry; injects TVStore + TVConnectionManager
├── Models/                     TVDevice, RemoteCommand/SSAPRequest, StreamingApp
├── Storage/TVStore.swift       UserDefaults-backed list of saved TVs
├── Services/
│   ├── SSAPClient.swift        webOS SSAP WebSocket + pairing + pointer socket
│   ├── SSDPDiscovery.swift     UDP/SSDP TV discovery
│   └── TVConnectionManager.swift  High-level @Observable state for the UI
├── Theme/                      Colors, design tokens
├── Components/                 RemoteKey, RockerControl, DirectionalPad, headers, AirPlay picker
└── Screens/                    Remote, Casting, Library, Apps, Onboarding
```
