# FramePullMobile — Context & Where We Left Off

**Last updated:** 2026-03-13 18:26 CET

---

## What This Project Is

An iOS port of the macOS "FramePull" app. It lets users load a video, scrub through it, snap still frames, mark in/out clip segments, and export the results to the Camera Roll. The app uses a "mark first, export later" workflow with a Tinder-style review interface.

## Project Location

```
/Users/carlooppermann/Dropbox/_02_PRE_PRODUCTION/Claude Projects/framepull mobile/FramePullMobile/
```

Built with `xcodegen` — run `xcodegen generate` to regenerate the `.xcodeproj` after any file additions/deletions.

## Architecture

```
Sources/
├── App/
│   ├── FramePullMobileApp.swift     # App entry point
│   ├── ContentView.swift            # Video picker (Files + PhotosPicker)
│   ├── SimpleVideoPlayerView.swift  # Main player UI (ErgonomicVideoPlayerView + PlayerModel)
│   ├── CustomVideoPlayer.swift      # UIViewControllerRepresentable wrapping AVPlayerViewController
│   ├── CustomTimelineView.swift     # Bottom scrubber with scene cut markers
│   ├── ReviewSelectionView.swift    # Tinder-style review modal (JUST REWRITTEN)
│   └── InteractableCard.swift       # OLD file — NEEDS TO BE DELETED (see below)
├── Core/
│   ├── VideoProcessor.swift         # Frame extraction engine (from macOS app)
│   ├── ProcessingUtilities.swift    # Helper utilities
│   ├── SceneDetector.swift          # Scene cut detection
│   ├── MarkingState.swift           # MarkedStill / MarkedClip models
│   └── BatchProcessor.swift         # Batch export to Camera Roll (JUST REWRITTEN)
└── Assets.xcassets/
    └── AppIcon.appiconset/          # App icons (all sizes generated)
```

## What Was Just Done (This Session)

### Completed ✅
1. **Deferred snapping** — SNAP button now only records timestamps (no instant export)
2. **Export button** — Appears top-right when items are marked, opens action sheet
3. **BatchProcessor rewrite** — Now extracts stills directly via `AVAssetImageGenerator` instead of going through `VideoProcessor` (which had a subdirectory bug causing exports to silently fail)
4. **ReviewSelectionView full rewrite** — Clean index-based single-card approach. Only one card renders at a time. Swipe animations complete fully before advancing. No more overlapping gesture conflicts.
5. **PhotosPicker added** — ContentView now has both a Files picker and a Photos Library picker
6. **App Icon generated** — All 18 iOS icon sizes created from the user's logo in `AppIcon.appiconset`
7. **Swift concurrency warnings fixed** — PlayerModel marked `@MainActor`, time observer wrapped properly

### NOT YET DONE ❌ (pick up here next session)

1. **Delete `InteractableCard.swift`** — This old file is no longer used. The new `ReviewSelectionView.swift` contains everything. Run:
   ```bash
   rm Sources/App/InteractableCard.swift
   xcodegen generate
   ```

2. **Add "Remove" button to main player** — User wants a button in the top-left corner of the video player to clear the current video and go back to the picker screen. This should be added to `ErgonomicVideoPlayerView` in `SimpleVideoPlayerView.swift`. Needs a callback/binding to set `selectedVideoURL = nil` in `ContentView`.

3. **Verify the build compiles** — After deleting `InteractableCard.swift` and regenerating, run:
   ```bash
   xcodegen generate
   xcodebuild -scheme FramePullMobile -destination 'generic/platform=iOS Simulator' build
   ```

4. **App Icon not showing on Simulator** — The icons ARE bundled (build succeeds), but the iOS Simulator aggressively caches SpringBoard. User needs to do: Simulator menu → Device → Erase All Content and Settings, then rebuild.

5. **Test the export flow end-to-end** — The BatchProcessor was rewritten but hasn't been tested yet on-device. The key fix was switching from `VideoProcessor.extractStillsAtTimestamps` (which saves to a `stills/` subdirectory) to direct `AVAssetImageGenerator` usage.

## Key Design Decisions

- **Mark first, export later**: Snapping is instant (just records timestamp). Heavy processing happens in batch at the end.
- **Tinder-style review**: Single card at a time, swipe right to keep, left to discard. Bottom buttons as alternative to gestures.
- **`xcodegen`** manages the Xcode project — always run `xcodegen generate` after adding/removing files.
- **`project.yml`** contains the build settings including `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`.

## Build Command

```bash
cd "/Users/carlooppermann/Dropbox/_02_PRE_PRODUCTION/Claude Projects/framepull mobile/FramePullMobile"
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme FramePullMobile -destination 'generic/platform=iOS Simulator' build
```

## Known Issues

- Export wasn't working because `VideoProcessor` saves frames into an `outputDir/stills/` subdirectory, but `BatchProcessor` was looking for them in `outputDir/` directly. **This has been fixed** in the rewritten `BatchProcessor.swift` by bypassing `VideoProcessor` entirely.
- The old `ReviewSelectionView` had overlapping `ForEach` + `InteractableCard` views causing gesture conflicts and animation freezes. **This has been fixed** with a clean single-card rewrite.
