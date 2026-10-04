import 'package:flutter/widgets.dart';

/// Breakpoints inspired by Bootstrap 5 (px)
class Breakpoints {
  static const double xs = 0;      // < 576
  static const double sm = 576;    // ≥ 576
  static const double md = 768;    // ≥ 768
  static const double lg = 992;    // ≥ 992
  static const double xl = 1200;   // ≥ 1200
  static const double xxl = 1400;  // ≥ 1400
}

/// Responsive layout utilities for Flutter
class ResponsiveLayout {
  final BuildContext context;

  ResponsiveLayout(this.context);

  double get width => MediaQuery.of(context).size.width;
  double get height => MediaQuery.of(context).size.height;
  Orientation get orientation => MediaQuery.of(context).orientation;

  /// Check if current width is within a breakpoint range
  bool get isXs => width < Breakpoints.sm;
  bool get isSm => width >= Breakpoints.sm && width < Breakpoints.md;
  bool get isMd => width >= Breakpoints.md && width < Breakpoints.lg;
  bool get isLg => width >= Breakpoints.lg && width < Breakpoints.xl;
  bool get isXl => width >= Breakpoints.xl && width < Breakpoints.xxl;
  bool get isXxl => width >= Breakpoints.xxl;

  /// Shorthand for common checks
  bool get isMobile => width < Breakpoints.md;
  bool get isTablet => width >= Breakpoints.md && width < Breakpoints.lg;
  bool get isDesktop => width >= Breakpoints.lg;

  /// Get responsive value based on screen size
  T responsiveValue<T>({
    T? xs,
    T? sm,
    T? md,
    T? lg,
    T? xl,
    T? xxl,
    required T fallback,
  }) {
    if (isXs && xs != null) return xs;
    if (isSm && sm != null) return sm;
    if (isMd && md != null) return md;
    if (isLg && lg != null) return lg;
    if (isXl && xl != null) return xl;
    if (isXxl && xxl != null) return xxl;
    return fallback;
  }

  /// Responsive column count (like Bootstrap grid)
  int get columnCount {
    if (isXs) return 1;
    if (isSm) return 2;
    if (isMd) return 3;
    if (isLg) return 4;
    return 6; // xl, xxl
  }
}

/// Extension for easy access
extension ResponsiveExt on BuildContext {
  ResponsiveLayout get responsive => ResponsiveLayout(this);
}

/// A widget that changes its child based on screen size
class ResponsiveWidget extends StatelessWidget {
  final WidgetBuilder xs;
  final WidgetBuilder? sm;
  final WidgetBuilder? md;
  final WidgetBuilder? lg;
  final WidgetBuilder? xl;
  final WidgetBuilder? xxl;

  const ResponsiveWidget({
    super.key,
    required this.xs,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.xxl,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout(context);
    if (r.isXxl && xxl != null) return xxl!(context);
    if (r.isXl && xl != null) return xl!(context);
    if (r.isLg && lg != null) return lg!(context);
    if (r.isMd && md != null) return md!(context);
    if (r.isSm && sm != null) return sm!(context);
    return xs(context);
  }
}

/// Responsive row that arranges children in columns based on screen size
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = ResponsiveLayout(context);
        int columns = r.columnCount;
        if (children.length <= 1) columns = 1;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: children.map((child) {
            return SizedBox(
              width: (constraints.maxWidth - (columns - 1) * spacing) / columns,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Responsive container that adjusts padding/margin
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = ResponsiveLayout(context);
        final responsivePadding = padding ??
            EdgeInsets.symmetric(
              horizontal: r.responsiveValue(
                xs: 16.0,
                sm: 24.0,
                md: 32.0,
                lg: 48.0,
                xl: 64.0,
                fallback: 80.0,
              ),
              vertical: r.responsiveValue(
                xs: 16.0,
                sm: 20.0,
                md: 24.0,
                lg: 28.0,
                xl: 32.0,
                fallback: 32.0,
              ),
            );

        return Container(
          margin: margin,
          padding: responsivePadding,
          constraints: maxWidth != null
              ? BoxConstraints(maxWidth: maxWidth!)
              : BoxConstraints(
                  maxWidth: r.responsiveValue(
                    xs: double.infinity,
                    sm: 540.0,
                    md: 720.0,
                    lg: 960.0,
                    xl: 1140.0,
                    fallback: 1320.0,
                  ),
                ),
          child: child,
        );
      },
    );
  }
}

/// Helper for responsive text scaling
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveLayout(context);
    final baseStyle = style ?? const TextStyle();
    final fontSize = baseStyle.fontSize ??
        r.responsiveValue(
          xs: 14.0,
          sm: 15.0,
          md: 16.0,
          lg: 17.0,
          xl: 18.0,
          fallback: 18.0,
        );

    return Text(
      text,
      style: baseStyle.copyWith(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}