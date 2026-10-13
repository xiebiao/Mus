import SwiftUI
import ServiceManagement
import MouseCore

private let accent = Color(red: 0.08, green: 0.47, blue: 0.42)

struct SettingsView: View {
    @Bindable var model: AppModel
    var onHide: () -> Void = {}
    @State private var page = 0
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
                            Image(systemName: "info.circle")
                            Text(notice).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                            Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                                .accessibilityLabel(L10n.text("关闭提示"))
                        }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    if page == 0 { mouseSettings }
                    else { usageSettings }
                }.padding(28)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 820, idealWidth: 850, minHeight: 650, idealHeight: 720)
        .tint(accent)
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
            HStack(spacing: 10) {
                Image(nsImage: BrandImages.logo)
                    .resizable().renderingMode(.template).interpolation(.high).scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mus").font(.headline)
                    Text(L10n.text("轻一点，刚刚好。")).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.bottom, 30).padding(.top, 12)
            navItem(L10n.text("鼠标设置"), icon: "slider.horizontal.3", index: 0)
            navItem(L10n.text("使用与权限"), icon: "checkmark.shield", index: 1)
            Spacer()
            Button(action: onHide) {
                Label(L10n.text("收起到状态栏"), systemImage: "menubar.arrow.up.rectangle")
                    .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).padding(.bottom, 8)
                .help(L10n.text("关闭设置窗口，Mus 继续在屏幕顶部状态栏运行"))
            Label(L10n.text("本机运行 · 无需账户"), systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            Text(L10n.text("v0.1.0 · macOS 原生应用")).font(.caption2).foregroundStyle(.tertiary).padding(.top, 3)
        }.padding(20).frame(width: 172)
            .frame(maxHeight: .infinity).background(.thinMaterial)
    }

    private func navItem(_ title: String, icon: String, index: Int) -> some View {
        Button { page = index } label: {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                .background(page == index ? accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(page == index ? accent : .primary)
        }.buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(page == 0 ? L10n.text("让鼠标顺手起来。") : L10n.text("简单设置，安心常驻。"))
                    .font(.system(size: 25, weight: .semibold))
                Text(page == 0 ? L10n.text("专注侧键与滚动，设置即时生效。") : L10n.text("只请求实现鼠标操作所需的权限。"))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(L10n.text("启用"), isOn: $model.settings.enabled).toggleStyle(.switch).labelsHidden()
                .accessibilityLabel(L10n.text("启用鼠标设置")).help(L10n.text("暂停后恢复系统鼠标行为"))
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.text("还差一步：允许辅助功能权限"), systemImage: "hand.raised.fill").font(.headline)
            Text(L10n.text("用于改写鼠标侧键和滚轮事件。打开系统设置，启用 Mus，再回到这里。"))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L10n.text("打开权限设置")) { model.openPermissionSettings() }.buttonStyle(.borderedProminent)
                Button(L10n.text("我已开启，重新检查")) { model.refresh() }
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(L10n.text("已检测的鼠标")).font(.headline)
                    Spacer()
                    Button(L10n.text("重新检测")) { model.refresh() }
                }
                if model.mice.isEmpty {
                    Label(L10n.text("未检测到鼠标"), systemImage: "computermouse")
                        .foregroundStyle(.secondary)
                    Text(L10n.text("请连接鼠标后重新检测。接收器可能无法提供具体型号。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.mice) { mouse in
                    HStack(spacing: 24) {
                        if mouse.isMXAnywhere3S {
                            MouseProductImage(learningRear: model.learningRear, highlightColor: accent)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "computermouse")
                                .font(.system(size: 58, weight: .ultraLight))
                                .frame(width: 120, height: 155).foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mouse.title).font(.title3.weight(.semibold))
                            Text("\(mouse.brand) · \(mouse.connection)").font(.caption).foregroundStyle(.secondary)
                            Label(L10n.text(mouse.isReceiver ? "已检测到接收器" : "已连接"), systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.medium)).foregroundStyle(accent)
                            if mouse.isReceiver {
                                Text(L10n.text("接收器未提供所连接鼠标的具体型号。"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
                Label(L10n.format("事件监听：%@", model.status), systemImage: model.running && model.settings.enabled ? "circle.fill" : "circle")
                    .font(.caption.weight(.medium)).foregroundStyle(model.running && model.settings.enabled ? accent : .secondary)
                if let rear = model.learningRear {
                    Label(L10n.text(rear ? "请按下后侧键；图中高亮为位置示意。" : "请按下前侧键；图中高亮为位置示意。"), systemImage: "hand.point.up.left.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(accent)
                }
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))

            Text(L10n.text("作用范围：所有鼠标的对应侧键与普通滚轮。触控板连续滚动保持不变。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            sectionTitle(L10n.text("侧键"), detail: L10n.text("把常用操作放在拇指旁"))
            VStack(spacing: 0) {
                buttonRow(title: L10n.text("前侧键"), detail: L10n.text("靠近鼠标头部的一颗"), rear: false, binding: $model.settings.front)
                Divider().padding(.horizontal, 16)
                buttonRow(title: L10n.text("后侧键"), detail: L10n.text("靠近手腕的一颗"), rear: true, binding: $model.settings.rear)
            }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            if let rear = model.learningRear {
                HStack {
                    Text(L10n.text(rear ? L10n.text("现在按一下后侧键（12 秒内）…") : L10n.text("现在按一下前侧键（12 秒内）…"))).font(.callout).foregroundStyle(accent)
                    Spacer()
                    Button(L10n.text("取消")) { model.cancelLearning() }
                }
            } else {
                Text(model.lastButton)
                    .font(.caption).foregroundStyle(.secondary)
            }
            sectionTitle(L10n.text("滚轮调节"), detail: L10n.text("按你的手感调整"))
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
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            sectionTitle(L10n.text("滚动方向"), detail: L10n.text("以 macOS 当前方向为基准"))
            VStack(alignment: .leading, spacing: 14) {
                Toggle(L10n.text("反转纵向滚动"), isOn: $model.settings.reverseVertical)
                Divider()
                Toggle(L10n.text("反转横向滚动"), isOn: $model.settings.reverseHorizontal)
            }.toggleStyle(.switch).padding(16)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
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
                Text(display).font(.callout.monospacedDigit()).foregroundStyle(accent)
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

    private func buttonRow(title: String, detail: String, rear: Bool, binding: Binding<ButtonBinding>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: rear ? "arrow.uturn.backward" : "arrow.uturn.forward")
                    .font(.title3).foregroundStyle(accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Picker(title, selection: binding.action) {
                    ForEach(ButtonAction.allCases) { action in Text(L10n.text(action.title)).tag(action) }
                }.labelsHidden().frame(width: 185).accessibilityLabel(L10n.format("%@操作", title))
                Button(L10n.text(model.learningRear == rear ? "识别中…" : "识别")) { model.learn(rear: rear) }.disabled(!model.running)
                    .help(L10n.text("按下对应侧键，识别实际按键编号"))
            }
            if binding.wrappedValue.action == .custom {
                ShortcutRecorder(shortcut: binding.custom).frame(height: 28)
                if binding.wrappedValue.custom == nil {
                    Text(L10n.text("录制前保持原始侧键行为。")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(16)
            .background(model.learningRear == rear ? accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 12))
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
                    instruction("2", L10n.text("允许辅助功能权限"), L10n.text("系统设置 → 隐私与安全性 → 辅助功能 → Mus。"))
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
                Button(L10n.text("重新检查权限")) { model.refresh() }
                Button(L10n.text("复制诊断信息")) { model.copyDiagnostics() }
                Spacer()
                Button(L10n.text("恢复默认…")) { showReset = true }
            }
        }
    }

    private func instruction(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.caption.bold()).foregroundStyle(accent).frame(width: 24, height: 24)
                .background(accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
