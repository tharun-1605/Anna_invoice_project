import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blurX;
  final double blurY;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxConstraints? constraints;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  final Color? color;
  final List<Color>? gradientColors;

  final bool applyBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.blurX = 16.0,
    this.blurY = 16.0,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.constraints,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
    this.color,
    this.gradientColors,
    this.applyBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);
    
    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.4),
        gradient: color == null && gradientColors != null
            ? LinearGradient(
                colors: gradientColors!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: effectiveBorderRadius,
        border: border ??
            Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
      ),
      child: child,
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      constraints: constraints,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: applyBlur
          ? ClipRRect(
              borderRadius: effectiveBorderRadius,
              clipBehavior: clipBehavior,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
                child: innerContainer,
              ),
            )
          : innerContainer,
    );
  }
}
