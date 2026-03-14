<p align="center">
  <img src="FramePullMobile/Sources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" alt="FramePull Mobile icon" />
</p>

<h1 align="center">FramePull Mobile</h1>

<p align="center">
  <strong>Extract stills, GIFs, and clips from any video — fast, local, no subscriptions. Now on iOS.</strong>
</p>

<p align="center">
  A native iOS app for filmmakers, editors, and creators to pull frames from footage on the go, without roundtripping through an NLE.
</p>

---

## What it does

Select a video on your iPhone and FramePull Mobile automatically processes it for scene cuts. Mark your favorite stills, set clip ranges with one-handed ergonomic controls, and review your selections Tinder-style before exporting directly to your Camera Roll.

- **Still frames** — High quality snaps directly from the video track
- **Video clips** — MP4 clip extraction based on custom In/Out points
- **"Auto Magic"** — Automatically distribute a set number of stills and clips across the video
- **Tinder-style Review** — A fun, rapid-fire card interface to "Keep" or "Nope" your marked shots

## Scene detection & Auto Magic

Like its macOS sibling, FramePull Mobile scans your video for scene cuts locally on your iPhone. No cloud processing, no API calls — it uses Apple's native frameworks to keep your media private.

Using the **Auto Magic** feature, you can tell the app to generate 10 stills and 5 clips. It mathematically spreads them across the timeline, and smartly snaps the generated clips to the nearest detected scene cuts for perfect alignment.

## Key features

| | |
|---|---|
| **Ergonomic Controls** | Big, thumb-friendly `IN`, `SNAP`, and `OUT` buttons for one-handed marking |
| **Scrubbable Timeline** | Fast visual timeline to scrub through footage and see all your markers |
| **Auto Magic** | Instantly generate evenly spaced stills and clips instantly across the video |
| **Swipe to Review** | A fun card stack interface to approve (`Right`) or reject (`Left`) your marks |
| **Background Processing** | Extracts and saves your media asynchronously without freezing the UI |
| **Custom Album** | Approved shots execute instantly and save to a clean `FramePull` album in Photos |
| **Reset All** | One-tap destructive clear to wipe the slate clean if you want to start over |

## Built with

Zero external dependencies. FramePull Mobile is built entirely on native Apple frameworks:

`AVFoundation` · `Photos` · `UIKit` · `SwiftUI`

## License

Copyright &copy; 2026 Carlo Oppermann. All rights reserved.
