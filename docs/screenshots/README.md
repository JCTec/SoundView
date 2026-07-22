# Simulator review screenshots

Captured on **2026-07-10** for design/product review.

| File | Device | Screen |
|------|--------|--------|
| `01-iphone-library-empty.png` | iPhone 17 | Empty library (production FileStore) |
| `02-iphone-library-seeded.png` | iPhone 17 | Library with on-disk packages + “On this iPhone” |
| `03-iphone-library-preview.png` | iPhone 17 | Library sample data (“Synced with iCloud”) |
| `04-iphone-stem-view.png` | iPhone 17 | Stacked stem lanes + transport |
| `05-iphone-separation.png` | iPhone 17 | Stem mode quality picker + progress |
| `06-iphone-recorder.png` | iPhone 17 | Recorder sheet |
| `07-ipad-desk.png` | iPad Pro 13″ | Split library + stem desk |

Regenerate:

```bash
# Requires Simulator; writes under /tmp/soundview-shots then copy here.
xcodebuild -scheme SoundView \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SoundViewUITests/ScreenshotReviewTests/testCaptureCompactReviewScreens test
```

Launch argument `-previewLibrary` uses sample packages without touching disk.
