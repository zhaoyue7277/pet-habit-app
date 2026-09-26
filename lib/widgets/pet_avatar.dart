import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import 'pet_3d_viewer.dart';

/// 宠物形象组件（代码绘制的占位图形）
///
/// **说明：** 截图中的宠物是精美插画（蓝色小怪兽 / 粉色独角兽），
/// 属于美术资源，此处用代码绘制圆润卡通造型作为**占位**。
/// 后续替换时：只需把 [_buildPlaceholder] 换成 `Image.asset(...)`，
/// 对外接口（size / moodState / isJumping 等）完全不变。
class PetAvatar extends StatefulWidget {
  PetAvatar({
    super.key,
    required this.pet,
    this.size = AppSizes.petHomeSize,
    this.moodState = PetMoodState.normal,
    this.isJumping = false,
    this.isSpinning = false,
    this.showGlow = false,
    this.onTap,
  });

  /// 宠物数据（决定品种颜色）
  final Pet? pet;

  /// 显示尺寸
  final double size;

  /// 情绪状态（影响表情与颜色）
  final PetMoodState moodState;

  /// 是否正在跳跃（点击互动）
  final bool isJumping;

  /// 是否正在转圈（点击互动）
  final bool isSpinning;

  /// 是否显示升级闪光
  final bool showGlow;

  /// 点击宠物回调
  ///
  /// 【为什么 2D 与 3D 都要这个回调】
  /// 2D 路径由外层 GestureDetector 直接接管，本来就能收到点击；
  /// 3D 路径的触摸被 WebView 内的 model-viewer 消费掉了，
  /// 必须由 viewer.html 判定后经 callHandler 回传，外层 GestureDetector
  /// 收不到 —— 所以需要在 3D 分支单独接上同一条回调。
  /// 这样业务层（宠物页）无论宠物是 2D 还是 3D，行为完全一致。
  final VoidCallback? onTap;

  @override
  State<PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<PetAvatar>
    with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _jumpController;
  late AnimationController _spinController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    // 呼吸感 idle 动画，让宠物显得有生命
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: AppSizes.durationCelebrate,
    );
  }

  @override
  void didUpdateWidget(PetAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isJumping && !oldWidget.isJumping) {
      _jumpController.forward(from: 0);
    }
    if (widget.isSpinning && !oldWidget.isSpinning) {
      _spinController.forward(from: 0);
    }
    if (widget.showGlow && !oldWidget.showGlow) {
      _glowController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _jumpController.dispose();
    _spinController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = widget.pet == null
        ? AppColors.primary
        : Color(widget.pet!.species.bodyColorValue);

    // ---------- v1.2：3D 模型品种直接渲染本地化 model-viewer ----------
    // 3D 品种有独立的 WebView / HtmlElementView 实现，自带呼吸与旋转动画，
    // 不再走代码绘制的 CustomPainter。
    // 注意：必须传完整 modelPath（含 3d/ 目录段），viewer 内部会拼成
    // assets/assets/3d/xxx.glb。若只传文件名会 404。
    final modelPath = widget.pet?.species.modelPath;
    if (modelPath != null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        // onTap 透传给 Pet3DViewer：3D 的点击由 WebView 内部判定后回传，
        // 不经过外层 GestureDetector（触摸被 model-viewer 消费了）。
        child: Pet3DViewer(modelPath: modelPath, onTap: widget.onTap),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _idleController,
        _jumpController,
        _spinController,
        _glowController,
      ]),
      builder: (context, _) {
        // 呼吸：轻微上下浮动
        final breathe = math.sin(_idleController.value * math.pi) * 4;

        // 跳跃：抛物线
        final jump = _jumpController.isAnimating
            ? math.sin(_jumpController.value * math.pi) * 40
            : 0.0;

        // 转圈：Y 轴旋转
        final spin = _spinController.value * math.pi * 2;

        return Transform.translate(
          offset: Offset(0, -breathe - jump),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(spin),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 升级闪光
                if (_glowController.isAnimating)
                  _buildGlow(bodyColor),
                _buildPlaceholder(bodyColor),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 升级闪光特效
  Widget _buildGlow(Color bodyColor) {
    final progress = _glowController.value;
    return Opacity(
      opacity: (1 - progress).clamp(0.0, 1.0),
      child: Container(
        width: widget.size * (1 + progress * 0.8),
        height: widget.size * (1 + progress * 0.8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9),
              AppColors.accent.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// 代码绘制的占位宠物
  ///
  /// 造型：圆润身体 + 两只角 + 大眼睛 + 腮红 + 小尾巴，
  /// 颜色由品种决定。这是**占位图形**，替换为真实插画时
  /// 只需把本方法改为 `Image.asset(pet.assetPath)`。
  Widget _buildPlaceholder(Color bodyColor) {
    final s = widget.size;
    final isSad = widget.moodState == PetMoodState.sad;
    final isHungry = widget.moodState == PetMoodState.hungry;
    final isSleepy = widget.moodState == PetMoodState.sleepy;

    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _PetPainter(
          bodyColor: bodyColor,
          moodState: widget.moodState,
        ),
        child: Stack(
          children: [
            // 表情符号（用于强化情绪表达）
            Positioned(
              top: s * 0.42,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  isSleepy
                      ? '😴'
                      : isSad
                          ? '🥺'
                          : isHungry
                              ? '😋'
                              : widget.moodState == PetMoodState.happy
                                  ? '😊'
                                  : '🙂',
                  style: TextStyle(fontSize: s * 0.16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 宠物形象绘制器
class _PetPainter extends CustomPainter {
  _PetPainter({
    required this.bodyColor,
    required this.moodState,
  });

  final Color bodyColor;
  final PetMoodState moodState;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 深色描边（卡通风格）
    final outline = Paint()
      ..color = bodyColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;

    final bodyPaint = Paint()..color = bodyColor;
    final lightPaint = Paint()..color = Color.lerp(bodyColor, Colors.white, 0.35)!;

    // ---------- 身体（圆润大椭圆） ----------
    final bodyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + h * 0.06),
      width: w * 0.72,
      height: h * 0.68,
    );
    canvas.drawOval(bodyRect, bodyPaint);
    canvas.drawOval(bodyRect, outline);

    // ---------- 肚皮高光 ----------
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + h * 0.16),
        width: w * 0.38,
        height: h * 0.34,
      ),
      lightPaint,
    );

    // ---------- 两只角 ----------
    final hornPaint = Paint()..color = Color.lerp(bodyColor, Colors.white, 0.15)!;
    final hornPath = Path()
      ..moveTo(center.dx - w * 0.24, center.dy - h * 0.24)
      ..lineTo(center.dx - w * 0.30, center.dy - h * 0.42)
      ..lineTo(center.dx - w * 0.10, center.dy - h * 0.30)
      ..close();
    canvas.drawPath(hornPath, hornPaint);
    canvas.drawPath(hornPath, outline);

    final hornPath2 = Path()
      ..moveTo(center.dx + w * 0.24, center.dy - h * 0.24)
      ..lineTo(center.dx + w * 0.30, center.dy - h * 0.42)
      ..lineTo(center.dx + w * 0.10, center.dy - h * 0.30)
      ..close();
    canvas.drawPath(hornPath2, hornPaint);
    canvas.drawPath(hornPath2, outline);

    // ---------- 眼睛 ----------
    final eyeY = center.dy - h * 0.06;
    final eyePaint = Paint()..color = const Color(0xFF2E3A45);
    final eyeWhite = Paint()..color = Colors.white;

    for (final dx in [-w * 0.14, w * 0.14]) {
      // 眼白
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + dx, eyeY),
          width: w * 0.14,
          height: h * 0.16,
        ),
        eyeWhite,
      );
      // 瞳孔（委屈时下垂）
      final pupilOffset = moodState == PetMoodState.sad ? h * 0.015 : 0.0;
      canvas.drawCircle(
        Offset(center.dx + dx, eyeY + pupilOffset),
        w * 0.045,
        eyePaint,
      );
    }

    // ---------- 腮红 ----------
    final blushPaint = Paint()..color = const Color(0x40FF9AA2);
    for (final dx in [-w * 0.26, w * 0.26]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + dx, center.dy + h * 0.06),
          width: w * 0.14,
          height: h * 0.07,
        ),
        blushPaint,
      );
    }

    // ---------- 小尾巴 ----------
    final tailPath = Path()
      ..moveTo(center.dx - w * 0.34, center.dy + h * 0.20)
      ..quadraticBezierTo(
        center.dx - w * 0.50, center.dy + h * 0.30,
        center.dx - w * 0.42, center.dy + h * 0.40,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PetPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.moodState != moodState;
  }
}
