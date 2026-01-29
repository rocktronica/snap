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
snap.sh - Voice-triggered camera snapshot tool

Captures snapshots from a selected camera when a voice trigger word is detected.
Saves timestamped images to a session folder.

Usage: snap.sh [OPTIONS]

Options:
  --trigger WORD           Voice trigger word (default: snap)
  --delay SECONDS          Camera warmup delay (default: 0)
  --trigger-sound NAME     System sound for trigger (default: tink)
  --complete-sound NAME    System sound for completion (default: glass)
  --camera NAME            Camera device name (skip prompt)
                           Use quotes if name contains spaces
  --microphone ID          Microphone device ID (skip prompt)
  --output-dir PATH        Output folder (default: local/TIMESTAMP)
  -h, --help               Show this help message
```

If not provided, `./snap.sh` will prompt from available camera and mic inputs.

Flag examples:

```bash
./snap.sh --trigger "take a photo now" --trigger-sound "Ping" --complete-sound "Glass"
```

```bash
./snap.sh --camera "Insta360 Link" --microphone 2 --output-dir ~/Pictures/snaps
```

## License

MIT License – See [LICENSE](LICENSE) file for details.
