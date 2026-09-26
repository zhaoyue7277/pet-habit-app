import 'package:flutter/material.dart';

/// 3D 宠物渲染组件（不支持平台的占位实现）
class Pet3DViewer extends StatelessWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
    this.onTap,
  });

  final String modelPath;
  final double? width;
  final double? height;

  /// 点击模型回调（不支持 3D 的平台直接忽略）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: const Icon(Icons.pets_rounded, size: 48),
    );
  }
}
