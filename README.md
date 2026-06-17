# cleanup-xcode

`cleanup-xcode` is a macOS shell script for cleaning Xcode files.

It can remove Xcode.app, Command Line Tools, simulator runtimes, simulator data,
DerivedData, archives, caches, logs, preferences, and related files.

## Options

- `--full`: remove Xcode.app, Command Line Tools, simulator runtimes, device data, caches, and related files.
- `--keep-base`: keep Xcode.app, Command Line Tools, and installed simulator runtimes. Remove generated data and caches.
- `--scan`: show known Xcode-related files. Does not delete anything.
- `--estimate-sizes`: estimate target sizes before removal. This can be slow.
- `--yes`: skip confirmation prompts for the selected mode.
- `--no-dock`: do not remove Xcode from the Dock.
- `--help`: show help.
