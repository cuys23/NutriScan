import 'package:flutter/material.dart';

/// Paper-noise texture overlay — 7% opacity fractal noise for editorial feel.
class SkPaperTexture extends StatelessWidget {
  const SkPaperTexture({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.05,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/noise.png'),
              repeat: ImageRepeat.repeat,
            ),
          ),
        ),
      ),
    );
  }
}
