# 图片资源目录

用于存放宠物插画、皮肤图片等（可选）。

当前宠物形象由 `lib/widgets/pet_avatar.dart` 中的 `CustomPainter`
**用代码绘制**（圆润卡通风格），因此没有图片也能正常显示。

## 替换为真实插画的方法

1. 把图片（建议 PNG，透明背景，512×512）放到本目录，例如 `pet_dragon.png`；
2. 修改 `lib/models/pet.dart` 中 `PetSpecies` 枚举，为其增加资源路径字段；
3. 修改 `lib/widgets/pet_avatar.dart` 的 `_buildPlaceholder()` 方法，
   把 `CustomPaint` 换成 `Image.asset(...)`。

其余所有调用方（首页 / 宠物中心 / 番茄钟 / 商店）**无需改动**。
