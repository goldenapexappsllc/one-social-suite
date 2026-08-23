import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays the 1PrivateSocial horizontal lockup. Falls back to a styled gold
/// "1" placeholder if assets/images/logo_mark.png is not present yet.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 300, this.height = 110});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_mark.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _Placeholder(size: height);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.goldGlow,
            AppColors.gold,
            AppColors.goldDeep,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '1',
          style: TextStyle(
            color: AppColors.black,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
