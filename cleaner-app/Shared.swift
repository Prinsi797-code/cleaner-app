//  Shared.swift — global helpers + shared UI components

import SwiftUI

// MARK: - Format Bytes
func formatBytes(_ bytes: Int64) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    f.allowsNonnumericFormatting = false
    return f.string(fromByteCount: bytes)
}

// MARK: - Format Duration
func formatDuration(_ seconds: TimeInterval) -> String {
    let t = Int(seconds)
    let h = t / 3600, m = (t % 3600) / 60, s = t % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                 : String(format: "%d:%02d", m, s)
}

// MARK: - Color from hex string (non-failable)
extension Color {
    init(hexString: String) {
        var h = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { self = .gray; return }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double(val         & 0xFF) / 255
        )
    }
}

// MARK: - Scanning View
struct ScanningView: View {
    let text: String
    let progress: Double
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.15), lineWidth: 10)
                    .frame(width: 120, height: 120)

                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(colors: [.purple, .pink],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .animation(.easeInOut, value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.title3).bold().foregroundColor(.purple)
                } else {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(colors: [.purple, .pink],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(rotation))
                        .frame(width: 120, height: 120)
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }
            }
            Text(text)
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(title).font(.title2).bold()
            Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: action) {
                Text(buttonTitle).bold().foregroundColor(.white)
                    .padding(.horizontal, 30).padding(.vertical, 12)
                    .background(LinearGradient(colors: [.purple, .pink],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String
    var body: some View {
        Text(message).font(.subheadline).bold().foregroundColor(.white)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.black.opacity(0.8)).clipShape(Capsule())
    }
}
