import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final FontWeight? fontWeight;
  final double? height;
  final TextStyle _style;

  const AppText._(
    this.text,
    this._style, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  });

  // Display styles
  const AppText.displayLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 36,
         fontWeight: FontWeight.w600,
         letterSpacing: 1.2,
         height: 1.2,
       );

  const AppText.displayMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 28,
         fontWeight: FontWeight.w500,
         letterSpacing: 0.8,
         height: 1.3,
       );

  const AppText.displaySmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 24,
         fontWeight: FontWeight.w500,
         letterSpacing: 0.6,
         height: 1.3,
       );

  // Headline styles
  const AppText.headlineLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 32,
         fontWeight: FontWeight.w600,
         letterSpacing: 0.8,
         height: 1.25,
       );

  const AppText.headlineMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 22,
         fontWeight: FontWeight.w500,
         letterSpacing: 0.5,
         height: 1.3,
       );

  const AppText.headlineSmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 20,
         fontWeight: FontWeight.w500,
         letterSpacing: 0.3,
         height: 1.35,
       );

  // Title styles
  const AppText.titleLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 18,
         fontWeight: FontWeight.w600,
         letterSpacing: 0.2,
         height: 1.4,
       );

  const AppText.titleMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 16,
         fontWeight: FontWeight.w500,
         letterSpacing: 0.15,
         height: 1.4,
       );

  const AppText.titleSmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 14,
         fontWeight: FontWeight.w500,
         letterSpacing: 0.1,
         height: 1.4,
       );

  // Body styles
  const AppText.bodyLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 16,
         fontWeight: FontWeight.w400,
         height: 1.5,
         letterSpacing: 0.15,
       );

  const AppText.bodyMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 14,
         fontWeight: FontWeight.w400,
         height: 1.4,
         letterSpacing: 0.2,
       );

  const AppText.bodySmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 12,
         fontWeight: FontWeight.w400,
         height: 1.4,
         letterSpacing: 0.4,
       );

  // Label styles
  const AppText.labelLarge(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 14,
         fontWeight: FontWeight.w500,
         height: 1.4,
         letterSpacing: 0.1,
       );

  const AppText.labelMedium(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 12,
         fontWeight: FontWeight.w500,
         height: 1.3,
         letterSpacing: 0.5,
       );

  const AppText.labelSmall(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 10,
         fontWeight: FontWeight.w500,
         height: 1.2,
         letterSpacing: 0.5,
       );

  // Caption style
  const AppText.caption(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.height,
  }) : _style = const TextStyle(
         fontFamily: 'Poppins',
         fontSize: 11,
         fontWeight: FontWeight.w400,
         height: 1.3,
         letterSpacing: 0.4,
       );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _style.copyWith(
        color: color,
        fontWeight: fontWeight ?? _style.fontWeight,
        height: height ?? _style.height,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// Extension for quick access to common font weights
extension AppTextFontWeights on AppText {
  static const FontWeight thin = FontWeight.w100;
  static const FontWeight extraLight = FontWeight.w200;
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;
  static const FontWeight black = FontWeight.w900;
}