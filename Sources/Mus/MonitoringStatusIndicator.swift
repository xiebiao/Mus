import SwiftUI

struct MonitoringStatusIndicator: View {
    let status: MonitoringStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label {
            Text(L10n.format("事件监听：%@", status.title))
        } icon: {
            if status == .running && !reduceMotion {
                Image(systemName: "circle.fill")
                    .keyframeAnimator(initialValue: 1.0, repeating: true) { dot, opacity in
                        dot.opacity(opacity)
                    } keyframes: { _ in
                        LinearKeyframe(1.0, duration: 0.6)
                        CubicKeyframe(0.45, duration: 0.2)
                        CubicKeyframe(1.0, duration: 0.2)
                    }
            } else {
                Image(systemName: status == .running ? "circle.fill" : "circle")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}
