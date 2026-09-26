import 'package:flutter/material.dart';

/// Central PyreChat palette.
///
/// Pyre stays unmistakably warm and fire-led, but the supporting colors avoid
/// bathing every surface in one saturated orange.
abstract final class PyreColors {
  // Brand / warmth.
  static const ember = Color(0xFFF47C48);
  static const emberDeep = Color(0xFFDF6038);
  static const emberSoft = Color(0xFFFFAC73);
  static const sunset = Color(0xFFF9B68C);
  static const emberWash = Color(0xFFFFE3D2);

  // Warm light surfaces.
  static const canvas = Color(0xFFFFFAF6);
  static const canvasWarm = Color(0xFFFBEFE7);
  static const paper = Color(0xFFFFFBF8);
  static const paperDim = Color(0xFFF5ECE6);

  // Dark surfaces.
  static const ink = Color(0xFF211713);
  static const panel = Color(0xFF2B1E19);
  static const panelSoft = Color(0xFF38251E);

  // Text on dark / panel surfaces.
  static const mute = Color(0xFFC8A895);

  // Text on ember surfaces.
  static const onEmber = Color(0xFFFFFBF8);
  static const onEmberSubtitle = Color(0xFF5A311F);
  static const onEmberError = Color(0xFF54170D);

  // Text on light surfaces.
  static const onPaper = ink;
  static const onPaperMuted = Color(0xFF745A4C);
  static const hintOnPaper = Color(0xFF9A7C6C);

  // Semantic.
  static const error = Color(0xFFFF9B83);
  static const errorOnPaper = Color(0xFFB43A2E);
  static const success = Color(0xFF47775B);

  // Signed-in app chrome.
  static const chatSubtitleOnEmber = Color(0xFF62341F);
  static const navInactive = Color(0xFF9C877A);
  static const chatPreview = Color(0xFF80695C);
  static const chatTime = Color(0xFFA18A7B);

  // Signed-in night / campfire surfaces.
  static const night = Color(0xFF08111B);
  static const nightRaised = Color(0xFF0F1823);
  static const nightCard = Color(0xE6161A20);
  static const nightCardStrong = Color(0xF01B1D22);
  static const nightLine = Color(0xFF2D3238);
  static const nightText = Color(0xFFF6F2EF);
  static const nightMuted = Color(0xFFAAA29E);
  static const emberGlow = Color(0xFFFF9A4F);
  static const emberHot = Color(0xFFFF5C24);
  static const emberGold = Color(0xFFFFC66E);
  static const online = Color(0xFF55C66E);
  static const away = Color(0xFFF1B444);
  static const busy = Color(0xFFF0634E);

  // Effects.
  static const sheenHighlight = Color(0xFFFFF1E8);
  static const dialogScrim = Color(0xB8211713);
}
