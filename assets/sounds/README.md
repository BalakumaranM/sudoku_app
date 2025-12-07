# Sound Effects Directory

This directory should contain the following sound files:

## Required Sound Files

- `click.mp3` - Futuristic blip/tech click sound for button presses
- `locked.mp3` - Low-pitch access denied sound for locked levels
- `game_start.mp3` - Warp speed/whoosh sound when starting a game
- `win.mp3` - Success chime/synth chord for game completion
- `ambient.mp3` - Space drone/ethereal pad for background music (looped)

## Sound Sources

You can find free futuristic UI sound effects from:
- Freesound.org (search for "UI click futuristic", "HUD beep", "soft sci-fi switch")
- Zapsplat.com
- OpenGameArt.org

For ambient music, search for:
- "Space Drone"
- "Ethereal Pad"
- "Deep Space Ambient"

The app will work without these sound files (silently fails), but for the full experience, these sounds should be added.

## Integration

The sounds are managed by `SoundManager` in `lib/utils/sound_manager.dart`:
- `playClick()` - Called on all button taps
- `playLocked()` - Called when tapping locked buttons
- `playGameStart()` - Called when starting a new game
- `playWinSound()` - Called when completing a level
- `playAmbientMusic()` - Starts looping ambient music (called on home screen)
- `stopAmbientMusic()` - Stops ambient music (called when entering game)
