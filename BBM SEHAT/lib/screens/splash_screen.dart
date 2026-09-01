import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.24),
          radius: 0.9,
          colors: [Color(0x332FE0A0), AppColors.bg],
          stops: [0, 0.6],
        ),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/logo-bbm.png', height: 58),
          const SizedBox(height: 14),
          Text('BBM Sehat', style: AppText.heading(size: 34, height: 1)),
          const SizedBox(height: 8),
          Text('Bergerak lebih, hidup lebih sehat.',
              style: AppText.body(size: 12.5, color: AppColors.mut)),
          const SizedBox(height: 64),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
              backgroundColor: AppColors.line,
            ),
          ),
        ]),
      ),
    );
  }
}
