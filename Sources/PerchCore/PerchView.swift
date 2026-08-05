import SwiftUI

struct PerchView: View {
    @ObservedObject var store: SessionStore
    var onJump: (SessionStatus) -> Void
    var onDismiss: (SessionStatus) -> Void
    let clock: Clock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BirdView().frame(width: 30, height: 26)
                Text("Perch").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            Divider()

            if store.sessions.isEmpty {
                VStack(spacing: 6) {
                    BirdView().frame(width: 44, height: 38).opacity(0.5)
                    Text("All caught up").foregroundStyle(.secondary).font(.callout)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.sessions) { row($0) }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder private func row(_ s: SessionStatus) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color(s)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.project)
                    .font(.system(size: 13, weight: s.state == .waiting ? .semibold : .regular))
                    .lineLimit(1)
                Text(elapsed(s)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { onDismiss(s) } label: {
                Image(systemName: "xmark").font(.system(size: 10))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).help("Dismiss")
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(s.state == .waiting ? Color.orange.opacity(0.12) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onJump(s) }
        .opacity(s.state == .working ? 0.7 : 1.0)
    }

    private func color(_ s: SessionStatus) -> Color {
        switch s.state {
        case .waiting: return .orange
        case .working: return .green
        case .ended: return .gray
        }
    }

    private func elapsed(_ s: SessionStatus) -> String {
        let since = s.state == .waiting ? (s.waitingSince ?? s.lastActivity) : s.lastActivity
        let secs = max(0, Int(clock.now() - since))
        let verb = s.state == .waiting ? "waiting" : "working"
        if secs < 60 { return "\(verb) \(secs)s" }
        if secs < 3600 { return "\(verb) \(secs / 60)m" }
        return "\(verb) \(secs / 3600)h"
    }
}
