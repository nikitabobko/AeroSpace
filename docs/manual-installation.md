# Manual installation

> [!NOTE]
> It's recommended to use homebrew. See [the README](../README.md#installation)

1. Download the latest available zip from [releases page](https://github.com/nikitabobko/AeroSpace/releases)
2. Unpack zip
3. Put unpacked `AeroSpace-v$VERSION/AeroSpace.app` to `/Applications`
4. Put unpacked `AeroSpace-v$VERSION/bin/aerospace` anywhere to `$PATH` (The step is optional. It is only needed if you want to be able to interact with AeroSpace from CLI)

## AeroSpace can't be opened because Apple cannot check it for malicious software.

If you see this message

> "AeroSpace.app" can't be opened because Apple cannot check it for malicious software.

**Option 1** to resolve the problem

```
xattr -d com.apple.quarantine /Applications/AeroSpace.app
```

**Option 2** to resolve the problem
1. navigate in Finder to /Applications/AeroSpace.app
2. Right mouse click
3. Open (yes, it's that stupid)

