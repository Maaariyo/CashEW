# Skins

A skin restyles CashEW without being part of its core. The app asks the active skin for colours,
surfaces and text styles at a fixed set of hooks; every hook returns `null` for "use Cashew's
default". With the **Cashew** skin selected, every hook returns `null` and the original Cashew code
paths run unchanged.

Users pick a skin in *Settings → Skin*. The choice is stored in the `skin` setting (older installs
that only have the `bohoGlass` on/off setting are migrated automatically).

## Files

| Path | What it is |
|---|---|
| `budget/lib/skins/skin.dart` | The `AppSkin` interface, `NoSkin` (original design), `activeSkin()`, and the few widgets the core uses to apply a skin (`SkinBackdrop`, `SkinBarSurface`) |
| `budget/lib/skins/registry.dart` | The list of skins shown in Settings |
| `budget/lib/skins/boho_glass/boho_glass_skin.dart` | The Boho Glass skin (light: bohemian glass, dark: Boho Night) |

Nothing outside `lib/skins/` refers to a specific skin.

## Adding a skin

1. Create `budget/lib/skins/<your_skin>/<your_skin>_skin.dart`:

   ```dart
   import 'package:budget/skins/skin.dart';
   import 'package:flutter/material.dart';

   class OceanSkin extends AppSkin {
     const OceanSkin();
     @override
     String get id => "ocean"; // stored in settings, never change it
     @override
     String get name => "Ocean";
     @override
     String get description => "Deep blues with soft surfaces";

     @override
     ColorScheme? colorScheme(Brightness brightness) => ColorScheme.fromSeed(
         seedColor: Color(0xFF1B6CA8), brightness: brightness);

     // Override only the hooks you need; the rest keep Cashew's defaults
   }
   ```

2. Add `OceanSkin()` to `registeredSkins` in `budget/lib/skins/registry.dart`.

3. Bundle any fonts or images the skin needs in `pubspec.yaml`.

## Hooks

| Hook | Used for |
|---|---|
| `colorScheme`, `appColors` | The whole theme (Material colour scheme and Cashew's named colours) |
| `backgroundColor`, `splashColor` | Tinted account/budget pages, system navigation bar, ripples |
| `backdropPainter` | Something painted behind every page. When set, page backgrounds become transparent |
| `rowFill`, `transactionRowFill`, `tileFill` | Fill of list rows, transaction rows and outlined tiles |
| `barStyle` | Collapsed app bars, the navigation bar and sticky date headers (fill, blur, border, shadow) |
| `cardShadow`, `fabShadow`, `budgetHeaderOpacity`, `addButtonColor` | Cards, the add button, budget card headers, "+" buttons |
| `chipSelectedColor`, `chipSelectedTextColor` | Selected chips (wallet, budget, transaction type pickers) |
| `navigationIndicatorColor`, `navigationIconColor` | Bottom navigation bar |
| `textStyle` | Restyle text, for example headings in a display font |

Need a hook that doesn't exist yet? Add it to `AppSkin` with a `null` default and call it from the
core as `activeSkin().yourHook(...) ?? <Cashew's original value>`.

## Rules

Switching skins must never break the app. In particular:

- **Skins return values, never widgets.** Colours, decorations, styles and painters only.
- **The structure of the widget tree must not depend on the skin** above anything with state.
  `SkinBackdrop` (around the whole app and every page) and the add button wrapper always build the
  same widgets and only change what they paint. If a wrapper were added or removed when switching
  skins, Flutter would rebuild everything below it from scratch: that is exactly what made wallets
  disappear in v5.4.3-ew.2. `test/skin_test.dart` guards against it.
- `SkinBarSurface` may wrap content only when nothing important lives below it (bar backgrounds,
  date header labels).

## Why skins are built in, not downloaded

Flutter apps can't load new code at runtime (and Google Play doesn't allow it), so a skin with its
own painting or logic has to be compiled into the app. A future option is a *data-only* skin format
(a JSON file with colours, radii and fonts) that could be imported at runtime and mapped onto the
same hooks.
