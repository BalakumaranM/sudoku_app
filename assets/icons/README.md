# Custom Icon Assets

This directory should contain custom icon images for the cosmic difficulty progression.

## Required Icons

For the full cosmic theme experience, add these custom icon assets:

### Difficulty Icons

- **`moon.png`** - Crescent moon icon for Easy difficulty
  - Recommended size: 48x48px or 64x64px
  - Style: Simple, clean outline or filled crescent moon
  - Color: Will be tinted by the app (cyan for unlocked, grey for locked)

- **`planet.png`** - Ringed planet (Saturn-like) icon for Medium difficulty
  - Recommended size: 48x48px or 64x64px
  - Style: Planet with visible rings
  - Color: Will be tinted by the app

- **`galaxy.png`** - Spiral galaxy icon for Expert difficulty
  - Recommended size: 48x48px or 64x64px
  - Style: Spiral galaxy with arms
  - Color: Will be tinted by the app

- **`blackhole.png`** - Black hole with accretion disk icon for Master difficulty
  - Recommended size: 48x48px or 64x64px
  - Style: Black hole with glowing accretion disk
  - Color: Will be tinted by the app

## Current Status

The app currently uses Material Icons as placeholders:
- Easy: `Icons.nightlight_round` (Moon placeholder)
- Medium: `Icons.circle` (Planet placeholder)
- Hard: `Icons.wb_sunny` (Star/Sun - this one works well)
- Expert: `Icons.blur_circular` (Galaxy placeholder)
- Master: `Icons.radio_button_checked` (Black Hole placeholder)

## How to Add Custom Icons

1. Create or download icon images in PNG format
2. Place them in this `assets/icons/` directory
3. Update `pubspec.yaml` to include the icons directory in assets
4. Modify `_getDifficultyIcon()` in `lib/main.dart` to use `Image.asset()` instead of `Icon()`

## Icon Sources

You can find free space-themed icons from:
- Flaticon.com (search for "moon", "saturn", "galaxy", "black hole")
- Icons8.com
- The Noun Project
- Custom design tools (Figma, Illustrator)

Make sure icons are licensed for commercial use if you plan to publish the app.
