import 'package:flutter/material.dart';

/// 3D 宠物渲染组件（不支持平台的占位实现）
class Pet3DViewer extends StatelessWidget {
  const Pet3DViewer({
    super.key,
    required this.modelPath,
    this.width,
    this.height,
  });

  final String modelPath;
  final double? width;
  final double? height;

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
