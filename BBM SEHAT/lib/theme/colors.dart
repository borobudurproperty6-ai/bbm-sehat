import 'package:flutter/material.dart';

/// Palette lifted from the BBM Sehat design (dark, near-black ground with a
/// mint-green accent used for both the brand color and GPS route lines).
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0D0D0D);
  static const card = Color(0xFF1A1A1A);
  static const card2 = Color(0xFF212121);
  static const line = Color(0x14FFFFFF); // rgba(255,255,255,.08)

  static const text = Color(0xFFF4F6F5);
  static const mut = Color(0xFF8B8F8C);
  static const dim = Color(0xFF565B58);

  static const accent = Color(0xFF2FE0A0);
  static const route = accent;
  static const accentDeep = Color(0xFF0F5F47);
  static const accentTint = Color(0x212FE0A0); // rgba(47,224,160,.13)

  static const amber = Color(0xFFF0B429);
  static const amberSoft = Color(0xFFFFCF5C);
  static const amberTint = Color(0x1EF0B429); // rgba(240,180,41,.12)

  static const gold = Color(0xFFE5B93A);
  static const silver = Color(0xFFC0C7CB);
  static const bronze = Color(0xFFC98A4F);
  static const violet = Color(0xFFA78BFA);
  static const sky = Color(0xFF5EC2E6);

  static const mapWater = Color(0xFF12222A);
  static const mapPark = Color(0xFF14231B);
  static const mapRoadMajor = Color(0xFF232323);
  static const mapRoadMinor = Color(0xFF1A1A1A);
}
