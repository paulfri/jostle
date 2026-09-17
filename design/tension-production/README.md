# Tension production icon

This directory contains the reproducible source for Jostle's **Tension** app and menu-bar icons.

## Generate

```sh
python3 design/tension-production/generate_icons.py
```

The generator requires Python 3 and Pillow 10 or newer. It rewrites the AppIcon and MenuIcon PNGs and their asset-catalog manifests deterministically. Every requested raster size is drawn independently at high resolution before one final downsample; the 16 px and 32 px app slots use optical minimum stroke weights rather than a blind master-image reduction.

- `tension-app-icon.svg` — inspectable 1024 × 1024 vector master
- `tension-menu-icon.svg` — inspectable 16 × 16 monochrome master
- `preview.html` — app-icon reduction and light/dark menu-bar inspection
- `generate_icons.py` — canonical geometry, raster generation, and manifests

The menu artwork is black plus alpha. `StatusMenuController` marks the loaded `NSImage` as a template so AppKit supplies the correct menu-bar color for light, dark, and highlighted states.
