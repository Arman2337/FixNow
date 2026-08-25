# Bundled fonts

`app_typography.dart` sets two font families that must be bundled here so the app
renders in the intended faces instead of the system serif/sans fallback.

Drop these five static TTF files into this folder, named **exactly** as below.
The `family:` strings must match `app_typography.dart` character-for-character
(`Playfair Display`, `Inter`) or Flutter silently falls back.

| Family           | Weight | Flutter `weight` | Expected filename                |
|------------------|--------|------------------|----------------------------------|
| Playfair Display | 600    | 600              | `PlayfairDisplay-SemiBold.ttf`   |
| Playfair Display | 700    | 700              | `PlayfairDisplay-Bold.ttf`       |
| Inter            | 400    | 400              | `Inter-Regular.ttf`              |
| Inter            | 500    | 500              | `Inter-Medium.ttf`               |
| Inter            | 600    | 600              | `Inter-SemiBold.ttf`             |

Only these weights are referenced by the type scale today (display/heading1 =
700, heading2/heading3 = 600; body/caption = 400, bodyLarge = 500, title/label =
600). Adding more weights later means adding both the file and a `pubspec.yaml`
entry.

## Where to get them

Both families are licensed under the SIL Open Font License 1.1 (free to bundle
and redistribute):

- Playfair Display — https://fonts.google.com/specimen/Playfair+Display
- Inter — https://fonts.google.com/specimen/Inter

Download the family, take the static instances for the weights above, and rename
to the filenames in the table. (Recent Inter releases ship static files named
`Inter_18pt-SemiBold.ttf` etc. and a variable font — use the plain static
instances and rename, or keep your own names and update `pubspec.yaml` to match.)

Keep the OFL license file for each family alongside these TTFs for attribution.
