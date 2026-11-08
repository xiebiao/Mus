import SwiftUI

struct MonitoringStatusIndicator: View {
    let status: MonitoringStatus

    var body: some View {
        Label {
            Text(L10n.format("事件监听：%@", status.title))
        } icon: {
            if status == .running {
                Image(systemName: "circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "circle")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}
