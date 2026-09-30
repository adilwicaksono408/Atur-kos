import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:atur_kos/services/auth_service.dart';

/// Ikon Google 'G' 4-warna resmi yang digambar secara presisi dengan CustomPainter
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double strokeWidth = width * 0.22;
    final center = Offset(width / 2, height / 2);
    final radius = (width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Warna resmi Google Brand
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);
    const blue = Color(0xFF4285F4);

    // 1. Arc Merah (Atas)
    paint.color = red;
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.52, false, paint);

    // 2. Arc Biru (Kanan Atas ke Kanan Bawah)
    paint.color = blue;
    canvas.drawArc(rect, -math.pi * 0.23, math.pi * 0.46, false, paint);

    // 3. Arc Hijau (Bawah)
    paint.color = green;
    canvas.drawArc(rect, math.pi * 0.23, math.pi * 0.52, false, paint);

    // 4. Arc Kuning (Kiri)
    paint.color = yellow;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 0.50, false, paint);

    // 5. Palang Horizontal Biru khas huruf 'G' Google
    final barPaint = Paint()
      ..color = blue
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTWH(
      center.dx - strokeWidth * 0.05,
      center.dy - (strokeWidth / 2),
      radius + (strokeWidth / 2) + (strokeWidth * 0.05),
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tombol Elegan "Masuk dengan Google"
class GoogleSignInButton extends StatefulWidget {
  final String label;
  final VoidCallback? onSuccess;

  const GoogleSignInButton({
    super.key,
    this.label = 'Lanjutkan dengan Google',
    this.onSuccess,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    final success = await AuthService.signInWithGoogle(
      context: context,
      onLoadingChanged: (loading) {
        if (mounted) {
          setState(() => _isLoading = loading);
        }
      },
    );

    if (success && mounted) {
      widget.onSuccess?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF1E40AF),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GoogleLogo(size: 20),
                  const SizedBox(width: 14),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
