# 开发与验证



```sh
swift test
build/Mus.app/Contents/MacOS/Mus --self-check
build/Mus.app/Contents/MacOS/Mus --list-mice
```

`--self-check` 输出版本、系统与当前进程权限；终端进程权限可能与 GUI 应用不同，应以界面状态为准。`--list-mice` 只列品牌、型号、连接方式，不输出序列号或蓝牙地址。应用内“复制诊断信息”可导出运行状态与调节参数，不包含按键输入或自定义快捷键内容。

当前 44 项自动化测试覆盖事件路由、侧键配对、系统快捷键标志、滚动距离与小数累计、平滑取消、设置迁移、设备分类及中英文资源一致性。测试不向桌面发送合成输入；通过测试不等于所有真实设备都已验证。手动验收记录见 [手动验收记录](VALIDATION.md)。

| 路径 | 职责 |
| --- | --- |
| `Sources/MouseCore/` | 设置模型、输入变换、快捷键事件构造与滚动计算 |
| `Sources/Mus/EventTapService.swift` | 系统鼠标事件监听与合成输入 |
| `Sources/Mus/ScrollService.swift` | 平滑滚动调度与取消 |
| `Sources/Mus/MouseDeviceMonitor.swift` | 被动 HID 设备发现与品牌、连接分类 |
| `Sources/Mus/AppModel.swift` | 设置持久化、权限、登录项、侧键识别 |
| `Sources/Mus/SettingsView.swift` | 原生设置界面 |
| `Sources/Mus/BrandImages.swift` | 侧栏与菜单栏图标，适配深浅色外观 |
| `Sources/Mus/Resources/` | 界面图片、中英文翻译和第三方声明 |
| `Resources/` | 应用元数据、正式图标、历史候选与来源记录 |
| `scripts/build-icon.sh` | 从选定剪影生成多尺寸 ICNS 与界面图标 |
| `scripts/build-app.sh` | 生成图标、构建、组装应用并签名 |

正式图标源为 `Resources/IconVariants/Mus-Mouse-Template.png`。应用、侧栏和菜单栏共用小鼠轮廓；后两者作为模板图像，在深色背景显示白色、浅色背景显示黑色。历史彩色图标与剪影候选保留，不参与默认构建。

## 隐私与卸载

设置保存在本机 UserDefaults（`local.mus.app`）。应用不监听全局键盘输入，不记录输入历史，没有网络或云同步逻辑。鼠标移动与主键点击仅用于取消平滑尾部，不改变这些输入。

空闲时没有滚动定时器；平滑期间以最多约 120 次／秒调度，结束即停止。设备变化由系统通知驱动，不持续轮询。识别侧键使用最长 12 秒的一次性定时器。

卸载时先关闭应用内登录启动，退出 Mus，再删除 `.app`；辅助功能条目可在系统设置中移除。删除应用不会自动清除本地偏好设置。
