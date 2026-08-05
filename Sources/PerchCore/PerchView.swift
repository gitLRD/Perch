import SwiftUI

/// Perch palette — black / white / Claude-orange.
enum Palette {
    static let ink    = Color(red: 26/255, green: 22/255, blue: 20/255)
    static let paper  = Color(red: 250/255, green: 249/255, blue: 245/255)
    static let orange = Color(red: 217/255, green: 119/255, blue: 87/255)
    static let grey   = Color(red: 138/255, green: 133/255, blue: 125/255)
}

struct PerchView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var bird: BirdController
    var onJump: (SessionStatus) -> Void
    var onDismiss: (SessionStatus) -> Void
    var onClose: () -> Void
    let clock: Clock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Palette.paper.opacity(0.12))
            if store.sessions.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(store.sessions) { row($0) }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.ink)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.orange.opacity(0.35), lineWidth: 1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        .padding(6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            BirdView(size: 22, pulse: bird.pulse).frame(width: 22, height: 22).clipped()
            Text("Perch")
                .font(.system(size: 15, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Palette.paper)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.paper.opacity(0.55))
            .help("Hide window (reopen from the menu bar)")
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            BirdView(size: 34, pulse: bird.pulse).frame(width: 34, height: 34).clipped().opacity(0.7)
            Text("All clear").foregroundStyle(Palette.grey).font(.callout)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 26)
    }

    @ViewBuilder private func row(_ s: SessionStatus) -> some View {
        let waiting = s.state == .waiting
        HStack(spacing: 9) {
            dot(s)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.project)
                    .font(.system(size: 13, weight: waiting ? .semibold : .regular))
                    .foregroundStyle(waiting ? Palette.paper : Palette.paper.opacity(0.6))
                    .lineLimit(1)
                Text(elapsed(s))
                    .font(.system(size: 11))
                    .foregroundStyle(waiting ? Palette.orange.opacity(0.85) : Palette.grey)
            }
            Spacer()
            Button { onDismiss(s) } label: {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.grey)
            .help("Mark done")
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(waiting ? Palette.orange.opacity(0.14) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onJump(s) }
    }

    @ViewBuilder private func dot(_ s: SessionStatus) -> some View {
        switch s.state {
        case .waiting:
            Circle().fill(Palette.orange).frame(width: 9, height: 9)
        case .working:
            Circle().strokeBorder(Palette.grey, lineWidth: 1.6).frame(width: 9, height: 9)
        case .ended:
            Circle().fill(Palette.grey.opacity(0.4)).frame(width: 9, height: 9)
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
