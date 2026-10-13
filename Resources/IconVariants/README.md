# Mus 小鼠应用图标

2026-10-14 使用内置 image_gen 工具，参考用户提供的棕色小鼠照片生成。

- `Mus-Mouse.png`：带透明外边缘的生成原图。
- `Mus-Mouse.icns`：macOS 图标，包含 16、32、128、256、512 像素及对应 2× 表示。
- 彩色版本已保留为候选。当前正式图标为 `Mus-Mouse-Template.png`：2026-10-14 用户最终选定的透明底黑色剪影，应用、侧栏与菜单栏使用同一来源。菜单栏与侧栏以模板形式适配深浅色外观。`scripts/build-icon.sh` 从正式图标生成 AppIcon.icns 和 MusLogo.png。
- 此图不是 Lucide 素材，不适用其 ISC 许可。参考照片的来源及授权尚未确认；生成转换不等于对参考照片权利的确认。

## 生成提示词

Use case: stylized-concept. Asset type: finished macOS application icon for Mus, square 1024x1024. Input image is subject reference, not a photo to paste. Create one polished friendly illustrated brown field mouse inspired by its warm chestnut-gold back, cream belly, large glossy black eye, small pink nose and rounded pink inner ears. Three-quarter side view facing left, compact rounded body, short visible paws and elegant curved tail contained within icon. Simplify fur into broad smooth shapes, subtle soft 3D clay-like volume, sophisticated restrained shading, clear silhouette readable at 32px. Center mouse large on deep teal rounded-square macOS icon tile with subtle tonal depth, inset about 5 percent from canvas, generous rounded corners. Mouse occupies around 76 percent of tile width. Strong warm subject/cool background contrast. Entire tile and subject contained, transparent pixels outside rounded-square tile, no outer white matte. No typography, letters, logos, badges, accessories, extra objects, scenery or watermarks. Output a single ready-to-use app icon, not a presentation/mockup or multiple variants.
