# Bundled fonts

`app_typography.dart` sets one font family that must be bundled here so the app
renders in the intended face instead of the system fallback.

Drop these static TTF files into this folder, named **exactly** as below.
The `family:` string must match `app_typography.dart` character-for-character
(`Inter`) or Flutter silently falls back.

| Family | Weight | Flutter `weight` | Filename |
|--------|--------|------------------|----------------------------------|
| Inter | 400 | 400 | `Inter-Regular.ttf` |
| Inter | 500 | 500 | `Inter-Medium.ttf` |
| Inter | 600 | 600 | `Inter-SemiBold.ttf` |
| Inter | 700 | 700 | `Inter-Bold.ttf` |

Only these weights are referenced by the type scale today (headings/prices =
700, labels/buttons = 600, emphasis = 500, body/caption = 400). Adding more
weights later means adding both the file and a `pubspec.yaml` entry.

## Where they came from

Inter is licensed under the SIL Open Font License 1.1 (free to bundle and
redistribute). The committed files are the static instances from Inter 4.1:

- https://github.com/rsms/inter/releases/tag/v4.1

The license ships alongside the TTFs as `Inter-LICENSE.txt`.

## Why bundled instead of fetched

The app previously pulled a font from the network at runtime via
`google_fonts`. That made text render in the system face until (and unless)
the fetch resolved, shift mid-session when it did, and rendered inconsistently
offline. Bundling removes all three failure modes and the dependency.
