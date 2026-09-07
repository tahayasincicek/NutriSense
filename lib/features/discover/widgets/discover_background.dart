import 'package:flutter/material.dart';

/// The same soft green circular motif used by the main application shell.
class DiscoverBackground extends StatelessWidget {
  const DiscoverBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Stack(children: [
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary
                              .withValues(alpha: dark ? .09 : .05))),
                ),
                Positioned(
                  bottom: -140,
                  right: -160,
                  child: Container(
                      width: 420,
                      height: 420,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            theme.colorScheme.primary
                                .withValues(alpha: dark ? .07 : .045),
                            theme.colorScheme.primary.withValues(alpha: 0),
                          ]))),
                ),
              ]),
            ),
          ),
        ),
        child,
      ]),
    );
  }
}
