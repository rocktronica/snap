# snap.sh

A voice-triggered camera snapshot shell script for macOS that captures images when a spoken keyword is detected.

(Almost entirely vibe-coded 😅)

## Overview

`snap.sh` lets you take snapshots from your Mac's camera using voice commands. Select a camera and microphone, choose a trigger word, and the script will listen for that word and capture images automatically. Perfect for hands-free photography or automated image capture workflows.

## Usage

Install dependencies via Homebrew:

```bash
brew install imagesnap
brew install sveinbjornt/hear/hear
```

Then:

```
./snap.sh -h

./snap.sh
```

If not provided, `./snap.sh` will prompt from available camera and mic inputs.

Flag examples:

```bash
./snap.sh --trigger "take my photo" --camera "Insta360 Link" --microphone 2
```

```bash
./snap.sh --timelapse 5 --output ~/Pictures/snaps
```

## Known Issues

- Running multiple `snap.sh` instances on the same microphone causes the second instance to fail silently (microphone access conflict with the `hear` command)

## License

MIT License – See [LICENSE](LICENSE) file for details.
