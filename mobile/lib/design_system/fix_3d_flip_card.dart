import 'dart:math' as math;
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:flutter/material.dart';

/// Interactive 3D Flippable Credit / Escrow Card widget.
///
/// Features:
/// - True 3D Y-axis perspective rotation via Matrix4
/// - Specular front face with EMV chip, holographic badge, and cardholder info
/// - Dark matte back face with magnetic stripe, CVV security box, and FixNow Escrow badge
/// - Smooth spring deceleration (800ms) with reduce-motion fallback
class Fix3DFlipCard extends StatefulWidget {
  const Fix3DFlipCard({
    this.cardNumber = '4829 •••• •••• 9281',
    this.cardHolder = 'ALEXANDER REED',
    this.expiry = '09/29',
    this.cvv = '742',
    this.onFlipped,
    super.key,
  });

  final String cardNumber;
  final String cardHolder;
  final String expiry;
  final String cvv;
  final ValueChanged<bool>? onFlipped;

  @override
  State<Fix3DFlipCard> createState() => _Fix3DFlipCardState();
}

class _Fix3DFlipCardState extends State<Fix3DFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnim;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flipAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) return;
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
    widget.onFlipped?.call(!_isFront);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return GestureDetector(
        onTap: _toggleFlip,
        child: _isFront ? _buildFront(context) : _buildBack(context),
      );
    }

    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (context, _) {
          final angle = _flipAnim.value * math.pi;
          final isShowingFront = _flipAnim.value <= 0.5;

          // 3D Matrix perspective rotation
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle);

          return Transform(
            alignment: FractionalOffset.center,
            transform: transform,
            child: isShowingFront
                ? _buildFront(context)
                : Transform(
                    alignment: FractionalOffset.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildBack(context),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 175,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0F172A), Color(0xFF1E1B4B)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2857F5).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Metallic Chip
              Container(
                width: 38,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              // Hologram badge
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Color(0xFF06B6D4),
                      Color(0xFFEC4899),
                      Color(0xFFFBBF24),
                      Color(0xFF06B6D4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Number
          Text(
            widget.cardNumber,
            style: const TextStyle(
              fontSize: 16,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
          // Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CARD HOLDER',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.cardHolder,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.8,
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.expiry,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 175,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Magnetic stripe
          Container(height: 38, color: Colors.black87),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CVV / CVC',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.cvv,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'FixNow 256-Bit Escrow Vault Protected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
