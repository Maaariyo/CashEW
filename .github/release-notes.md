CashEW is an open source fork of [Cashew](https://github.com/jameskokoska/Cashew) with every Cashew Pro feature unlocked, the Boho Glass / Boho Night design, Trek & Travel trips and copyable daily expense logs. See the [README](https://github.com/Maaariyo/CashEW#readme) for details.

## Which file to download

| File | For |
|---|---|
| `CashEW-…-arm64-v8a.apk` | Almost every Android phone from 2017 onwards. **Pick this one if unsure.** |
| `CashEW-…-armeabi-v7a.apk` | Older 32-bit phones |
| `CashEW-…-x86_64.apk` | Emulators and Chromebooks |
| `CashEW-…-universal.apk` | Any device (larger download) |
| `SHA256SUMS.txt` | Checksums to verify the download |

## Installing

1. Download the APK on your phone and open it.
2. Allow your browser or file manager to install unknown apps when Android asks.
3. Google Play Protect may warn that the app is unknown; this is expected for apps installed outside the Play Store.

CashEW installs alongside the original Cashew (different app id). To move your data, use *Export Cashew Data File* in Cashew and *Import Cashew Data File* in CashEW (Settings → Import & Export).

## Known limitations

- Unless the repository has a signing key configured, each release is signed with a different temporary key. A newer APK then won't install over an older one: export your data, uninstall, install the new version and import.
- Google Drive backup and shared budgets need your own Google Cloud / Firebase setup ([docs/FIREBASE.md](https://github.com/Maaariyo/CashEW/blob/HEAD/docs/FIREBASE.md)). Local backups, CSV import and export work out of the box.
