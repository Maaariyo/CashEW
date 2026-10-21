// Skins restyle CashEW without being part of its core.
//
// The app asks the active skin for colours, surfaces and text styles at a
// fixed set of hooks. Every hook returns null for "use Cashew's default", so
// with no skin (or the NoSkin entry) the original code paths run unchanged.
//
// Rules for skins, so switching never breaks the app:
// - Only return values (colours, decorations, styles, painters). Skins never
//   build or wrap widgets themselves.
// - The widgets in this file keep the same structure whether or not a skin is
//   active, so toggling a skin restyles the app without rebuilding app state.
//
// To add a skin: implement AppSkin in lib/skins/<name>/ and add it to
// registeredSkins in lib/skins/registry.dart. See docs/SKINS.md.
import 'dart:ui';

import 'package:budget/colors.dart';
import 'package:budget/skins/registry.dart';
import 'package:budget/struct/settings.dart';
import 'package:flutter/material.dart';

enum SkinBar { appBar, navigationBar, stickyHeader }

class SkinBarStyle {
  const SkinBarStyle(
      {required this.fill, this.blur = 0, this.border, this.shadow});
  final Color fill;
  // Backdrop blur sigma, 0 for none
  final double blur;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
}

abstract class AppSkin {
  const AppSkin();

  String get id;
  String get name;
  String get description;

  // Theme
  ColorScheme? colorScheme(Brightness brightness) => null;
  AppColors? appColors(Brightness brightness) => null;
  // Page background for account/budget tinted pages and the system nav bar
  Color? backgroundColor(Brightness brightness) => null;
  Color? splashColor(Brightness brightness) => null;

  // Painted behind every page. When set, scaffolds become transparent
  CustomPainter? backdropPainter(Brightness brightness) => null;

  // Surfaces
  // Tappable rows and settings rows that sit on the page background
  Color? rowFill(Brightness brightness) => null;
  Color? transactionRowFill(Brightness brightness) => null;
  // Outlined tiles, such as the More Actions grid
  Color? tileFill(Brightness brightness) => null;
  SkinBarStyle? barStyle(Brightness brightness, SkinBar bar) => null;
  List<BoxShadow>? cardShadow(Brightness brightness, {required bool sharp}) =>
      null;
  List<BoxShadow>? fabShadow(Brightness brightness) => null;
  double? budgetHeaderOpacity(Brightness brightness) => null;
  Color? addButtonColor(Brightness brightness) => null;

  // Selected chips in pickers (wallet, budget, transaction type...)
  Color? chipSelectedColor(ColorScheme colorScheme) => null;
  Color? chipSelectedTextColor(ColorScheme colorScheme) => null;

  Color? navigationIndicatorColor(Brightness brightness) => null;
  Color? navigationIconColor(Brightness brightness, {required bool selected}) =>
      null;

  // Restyle text, for example to set headings in a display font
  TextStyle? textStyle(TextStyle style,
          {required double fontSize,
          required FontWeight fontWeight,
          required Brightness brightness}) =>
      null;
}

// Cashew's original design
class NoSkin extends AppSkin {
  const NoSkin();
  @override
  String get id => "none";
  @override
  String get name => "Cashew";
  @override
  String get description => "The original Cashew design";
}

const String defaultSkinId = "bohoGlass";

String activeSkinId() {
  String? id = appStateSettings["skin"];
  if (id != null) return id;
  // Before skins, Boho Glass was a single on/off setting
  if (appStateSettings["bohoGlass"] == false) return "none";
  return defaultSkinId;
}

AppSkin activeSkin() {
  String id = activeSkinId();
  for (AppSkin skin in registeredSkins) {
    if (skin.id == id) return skin;
  }
  return const NoSkin();
}

bool skinPaintsBackdrop(Brightness brightness) =>
    activeSkin().backdropPainter(brightness) != null;

// Paints the active skin's backdrop behind [child]. The structure is the same
// with or without a skin, so switching skins never remounts [child].
class SkinBackdrop extends StatelessWidget {
  const SkinBackdrop({this.child, super.key});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    CustomPainter? painter =
        activeSkin().backdropPainter(Theme.of(context).brightness);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: painter)),
        ),
        child ?? SizedBox.expand(),
      ],
    );
  }
}

// Background of a bar from the active skin. Without a style it returns
// [child] as is, so it should only wrap content without important state.
class SkinBarSurface extends StatelessWidget {
  const SkinBarSurface({required this.bar, required this.child, super.key});
  final SkinBar bar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    SkinBarStyle? style =
        activeSkin().barStyle(Theme.of(context).brightness, bar);
    if (style == null) return child;
    return buildSkinBarSurface(style, child);
  }
}

Widget buildSkinBarSurface(SkinBarStyle style, Widget child) {
  Widget surface = DecoratedBox(
    decoration: BoxDecoration(
      color: style.fill,
      border: style.border,
      boxShadow: style.shadow,
    ),
    child: child,
  );
  if (style.blur <= 0) return surface;
  return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: style.blur, sigmaY: style.blur),
      child: surface,
    ),
  );
}
