# greeg app

Private client build with Supabase key activation and automatic bundled patches.

## What this build does

- Shows the app as `greeg app`.
- Requires a Supabase license key before opening the app.
- Consumes each key one time on the server.
- Creates the internal `Asset Indexer`, `Shaders`, and `144 fps` patches automatically after activation.
- Lets the client use `Apply`, `Original`, and name editing only.
- Hides Files, Cleaner, Wallpapers, patch creation, import, export, and editing.

## Included private payloads

The bundled payload files live in:

```text
ThreeOneOSFive/BundledPatchPayloads/
```

Included names:

```text
assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D
shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D
com.dts.freefireth.plist
```

Patch targets:

```text
Asset Indexer:
Documents/contentcache/Compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D

Shaders:
Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D

144 fps:
Library/Preferences/com.dts.freefireth.plist
```

See `GREEG_BUILD_GUIDE.md` for Supabase setup and GitHub Actions build steps.
