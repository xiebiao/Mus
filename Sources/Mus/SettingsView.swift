import SwiftUI
import ServiceManagement
import MouseCore

private extension View {
    func settingsCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return background(SettingsPalette.surfaceLow, in: shape)
            .overlay { shape.strokeBorder(SettingsPalette.outlineVariant.opacity(0.72), lineWidth: 0.75).allowsHitTesting(false) }
    }
}

private struct SettingsGroupStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label.font(.headline)
            configuration.content
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).settingsCard()
    }
}

private enum MouseSettingsTab {
    case sideButtons
    case scroll
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var page = 0
    @State private var mouseTab = MouseSettingsTab.sideButtons
    @State private var showReset = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if !model.hasPermission { permissionBanner }
                    else if !model.running { restartBanner }
                    if let notice = model.notice {
                        HStack(alignment: .top) {
                            MaterialSymbol.info.icon(18)
                            Text(notice).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                            Button { model.notice = nil } label: { MaterialSymbol.close.icon(16) }.buttonStyle(.plain)
                                .accessibilityLabel(L10n.text("关闭提示"))
                        }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    if page == 0 { mouseSettings }
                    else { usageSettings }
                }.padding(28)
            }
            .background(SettingsPalette.surface)
        }
        .frame(minWidth: 820, idealWidth: 850, minHeight: 650, idealHeight: 720)
        .groupBoxStyle(SettingsGroupStyle())
        .foregroundStyle(SettingsPalette.onSurface)
        .tint(SettingsPalette.primary)
        .id(model.language)
        .environment(\.locale, Locale(identifier: model.language.code))
        .onDisappear { model.cancelLearning() }
        .onChange(of: page) { _, _ in model.cancelLearning() }
        .alert(L10n.text("恢复默认设置？"), isPresented: $showReset) {
            Button(L10n.text("取消"), role: .cancel) {}
            Button(L10n.text("恢复")) { model.resetSettings() }
        } message: { Text(L10n.text("侧键恢复为后退与前进，滚动方向跟随系统。开机启动设置不变。")) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 4) {
                Image(nsImage: BrandImages.logo)
                    .resizable().renderingMode(.template).interpolation(.high).scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36).accessibilityHidden(true)
                Text("Mus").font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16).padding(.top, 4)
            navItem(L10n.text("鼠标设置"), icon: .tune, index: 0)
            navItem(L10n.text("使用与权限"), icon: .permissions, index: 1)
            sidebarDevices
                .padding(.top, 12)
            Text(verbatim: "v" + AppResources.version)
                .font(.caption2).foregroundStyle(SettingsPalette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 3)
        }.padding(16).frame(width: 198)
            .frame(maxHeight: .infinity).background(SettingsPalette.surfaceContainer)
    }

    private var sidebarDevices: some View {
        ScrollView {
            VStack(spacing: 18) {
                if model.mice.isEmpty {
                    MaterialSymbol.mouse.label(L10n.text("未检测到鼠标"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(model.mice) { mouse in
                    VStack(spacing: 8) {
                        if mouse.isMXAnywhere3S {
                            MouseProductImage(learningRear: model.learningRear, highlightColor: Color(red: 0.34, green: 0.33, blue: 0.64))
                                .padding(8)
                                .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 18))
                                .accessibilityHidden(true)
                        } else {
                            MaterialSymbol.mouse.icon(42)
                                .foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                        Text(mouse.title).font(.headline)
                        Text("\(mouse.brand) · \(mouse.connection)")
                            .font(.caption).foregroundStyle(.secondary)
                        MaterialSymbol.connected.label(L10n.text(mouse.isReceiver ? "已检测到接收器" : "已连接"), size: 14)
                            .font(.caption.weight(.semibold)).foregroundStyle(SettingsPalette.onPrimaryContainer)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(SettingsPalette.primaryContainer, in: Capsule())
                        if mouse.isReceiver {
                            Text(L10n.text("接收器未提供所连接鼠标的具体型号。"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(10).frame(maxWidth: .infinity)
                    .settingsCard()
                }
                Toggle(L10n.text("侧键与滚轮"), isOn: $model.settings.enabled)
                    .toggleStyle(.switch).controlSize(.small).font(.callout)
                    .fixedSize()
                    .help(L10n.text("暂停后恢复系统鼠标行为"))
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func navItem(_ title: String, icon: MaterialSymbol, index: Int) -> some View {
        Button { page = index } label: {
            icon.label(title, size: 20).font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(page == index ? SettingsPalette.primaryContainer : .clear, in: Capsule())
                .foregroundStyle(page == index ? SettingsPalette.onPrimaryContainer : SettingsPalette.onSurfaceVariant)
        }.buttonStyle(.plain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(page == 0 ? "鼠标设置" : "使用与权限"))
                .font(.system(size: 28, weight: .medium))
            Label(L10n.format("事件监听：%@", model.status), systemImage: model.running && model.settings.enabled ? "circle.fill" : "circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            MaterialSymbol.hand.icon(24)
                .foregroundStyle(SettingsPalette.primary)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text(model.waitingForPermission ? "等待辅助功能权限" : "还差一步：允许辅助功能权限"))
                    .font(.headline)
                Text(L10n.text(model.waitingForPermission
                    ? "在辅助功能列表中开启 Mus。如果列表中没有 Mus，点“+”添加。授权后会自动开始监听。"
                    : "允许 Mus 使用辅助功能，以调整鼠标侧键和滚动。"))
                    .font(.callout).foregroundStyle(SettingsPalette.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                model.openPermissionSettings()
            } label: {
                Text(L10n.text(model.waitingForPermission ? "返回权限设置" : "打开权限设置"))
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .foregroundStyle(SettingsPalette.onPrimary)
                    .background(SettingsPalette.primary, in: Capsule())
            }.buttonStyle(.plain).fixedSize()
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsPalette.secondaryContainer, in: RoundedRectangle(cornerRadius: 18))
    }

    private var restartBanner: some View {
        HStack {
            Text(L10n.text("权限已开启，但监听未启动。可重新尝试，必要时退出后重开。"))
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Button(L10n.text("重新启动监听")) { model.refresh() }
        }.padding(14).background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var mouseSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 0) {
                tabButton(.sideButtons, title: L10n.text("侧键"))
                tabButton(.scroll, title: L10n.text("滚轮调节"))
                Spacer(minLength: 0)
            }
            .background(alignment: .bottom) { Divider() }
            .onChange(of: mouseTab) { _, _ in model.cancelLearning() }

            switch mouseTab {
            case .sideButtons: sideButtonSettings
            case .scroll: scrollSettings
            }

            Text(L10n.text("作用范围：所有鼠标的对应侧键与普通滚轮。触控板连续滚动保持不变。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tabButton(_ tab: MouseSettingsTab, title: String) -> some View {
        let selected = mouseTab == tab
        return Button { mouseTab = tab } label: {
            Text(title).font(.system(size: 14, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? SettingsPalette.primary : SettingsPalette.onSurfaceVariant)
                .padding(.vertical, 12).padding(.horizontal, 22)
                .overlay(alignment: .bottom) {
                    Capsule().fill(selected ? SettingsPalette.primary : Color.clear)
                        .frame(height: 3).padding(.horizontal, 14)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var sideButtonSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                buttonCard(title: L10n.text("前侧键"), detail: L10n.text("靠近鼠标头部的一颗"), rear: false, binding: $model.settings.front)
                buttonCard(title: L10n.text("后侧键"), detail: L10n.text("靠近手腕的一颗"), rear: true, binding: $model.settings.rear)
            }
            if let rear = model.learningRear {
                HStack {
                    Text(L10n.text(rear ? "现在按一下后侧键（12 秒内）…" : "现在按一下前侧键（12 秒内）…")).font(.callout).foregroundStyle(SettingsPalette.primary)
                    Spacer()
                    Button(L10n.text("取消")) { model.cancelLearning() }
                }
            } else {
                Text(model.lastButton)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var scrollSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(L10n.text("自定义滚动"), isOn: $model.settings.scroll.enabled)
                Text(L10n.text("调低速度和步长可精细滚动，开启平滑可减少跳动。"))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if model.settings.scroll.enabled {
                    Divider()
                    scrollSlider("滚动速度", value: $model.settings.scroll.speed, range: 0.25...3, step: 0.05,
                                 display: String(format: "%.2f×", model.settings.scroll.speed), low: "更慢", high: "更快")
                    scrollSlider("最小步长", value: $model.settings.scroll.minimumStep, range: 1...80, step: 1,
                                 display: L10n.format("%d 像素", Int(model.settings.scroll.minimumStep)), low: "更精细", high: "更大步")
                    Divider()
                    Toggle(L10n.text("平滑滚动"), isOn: $model.settings.scroll.smooth)
                    if model.settings.scroll.smooth {
                        scrollSlider("平滑时长", value: $model.settings.scroll.duration, range: 0.08...0.6, step: 0.02,
                                     display: L10n.format("%d 毫秒", Int((model.settings.scroll.duration * 1000).rounded())), low: "更跟手", high: "更柔和")
                    }
                    Button(L10n.text("恢复滚轮默认值")) { model.settings.scroll = ScrollSettings() }
                }
            }.toggleStyle(.switch).padding(16)
                .settingsCard()
            sectionTitle(L10n.text("滚动方向"), detail: L10n.text("以 macOS 当前方向为基准"))
            VStack(alignment: .leading, spacing: 14) {
                Toggle(L10n.text("反转纵向滚动"), isOn: $model.settings.reverseVertical)
                Divider()
                Toggle(L10n.text("反转横向滚动"), isOn: $model.settings.reverseHorizontal)
            }.toggleStyle(.switch).padding(16)
                .settingsCard()
            Text(L10n.text("仅调节普通鼠标滚轮，触控板与 Magic Mouse 连续滚动保持原样。请避免同时启用其他软件的平滑滚动。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scrollSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
                              display: String, low: String, high: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(L10n.text(title)).font(.callout)
                Spacer()
                Text(display).font(.callout.monospacedDigit()).foregroundStyle(SettingsPalette.primary)
            }
            Slider(value: value, in: range, step: step).accessibilityLabel(L10n.text(title))
            HStack {
                Text(L10n.text(low))
                Spacer()
                Text(L10n.text(high))
            }.font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func buttonCard(title: String, detail: String, rear: Bool, binding: Binding<ButtonBinding>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                (rear ? MaterialSymbol.undo : .redo).icon(21)
                    .font(.headline).foregroundStyle(SettingsPalette.primary).frame(width: 36, height: 36)
                    .background(SettingsPalette.primaryContainer, in: Circle())
                    .accessibilityHidden(true)
                Spacer()
                Button(L10n.text(model.learningRear == rear ? "识别中…" : "识别")) { model.learn(rear: rear) }
                    .disabled(!model.running).controlSize(.small)
                    .help(L10n.text("按下对应侧键，识别实际按键编号"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Picker(title, selection: binding.action) {
                ForEach(ButtonAction.allCases) { action in Text(L10n.text(action.title)).tag(action) }
            }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(L10n.format("%@操作", title))
            if binding.wrappedValue.action == .custom {
                ShortcutRecorder(shortcut: binding.custom).frame(height: 28)
                if binding.wrappedValue.custom == nil {
                    Text(L10n.text("录制前保持原始侧键行为。")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .settingsCard()
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(model.learningRear == rear ? SettingsPalette.primary : .clear, lineWidth: 2).allowsHitTesting(false) }
    }

    private var usageSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(L10n.text("运行设置")) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker(L10n.text("界面语言"), selection: $model.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    Text(L10n.text("立即生效，无需重启。"))
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Toggle(L10n.text("登录 Mac 时启动"), isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                        .toggleStyle(.switch)
                    if model.loginNeedsApproval {
                        Button(L10n.text("在系统设置中允许登录项")) { SMAppService.openSystemSettingsLoginItems() }
                    }
                    Text(L10n.text("关闭窗口后保留菜单栏图标。菜单中可随时暂停或退出。"))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(L10n.text("首次使用")) {
                VStack(alignment: .leading, spacing: 14) {
                    instruction("1", L10n.text("保持鼠标连接"), L10n.text("蓝牙或 Bolt 接收器均可，不需要重新配对。"))
                    if model.hasPermission {
                        MaterialSymbol.connected.label(L10n.text("辅助功能权限已开启"))
                            .font(.callout).foregroundStyle(SettingsPalette.primary)
                    } else {
                        instruction("2", L10n.text("允许辅助功能权限"), L10n.text("系统设置 → 隐私与安全性 → 辅助功能 → Mus。"))
                    }
                    instruction("3", L10n.text("避免重复映射"), L10n.text("先退出 Options+、Mos 等工具的鼠标映射／滚动处理，再测试侧键和滚轮。"))
                    instruction("4", L10n.text("测试并选择操作"), L10n.text("在浏览器中测试前进和后退；在页面上滚动，确认方向。系统快捷键以你在 macOS 中的配置为准。"))
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox(L10n.text("第一版的范围")) {
                Text(L10n.text("此版本使用 macOS 标准鼠标事件，不识别特定鼠标连接状态，也不读取电量或修改 DPI、SmartShift。侧键映射同样适用于其他鼠标。前进／后退使用 ⌘[ / ⌘]，可按应用需要改为自定义快捷键。\n\n仅保存你的设置；无网络请求、无使用统计，不记录键盘输入。设置不会写入鼠标，退出应用后恢复原始行为。"))
                    .font(.callout).foregroundStyle(.secondary).lineSpacing(4).padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(L10n.text("复制诊断信息")) { model.copyDiagnostics() }
                Spacer()
                Button(L10n.text("恢复默认…")) { showReset = true }
            }
        }
    }

    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.bold()).foregroundStyle(SettingsPalette.primary).frame(width: 24, height: 24)
                .background(SettingsPalette.primaryContainer, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
