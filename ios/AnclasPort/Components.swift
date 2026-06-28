import SwiftUI

// MARK: - 共通カード背景

struct AnclasCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

extension View {
    /// アプリ共通のカード装飾（角丸 + 微シャドウ）
    func anclasCard(padding: CGFloat = 16) -> some View {
        modifier(AnclasCard(padding: padding))
    }
}

// MARK: - セクション見出し

struct SectionLabel: View {
    let text: String
    var icon: String? = nil
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.caption.weight(.bold))
            }
            Text(text)
                .font(.subheadline.weight(.bold))
                .tracking(0.5)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

// MARK: - ローディング状態（エンブレムのパルス）

struct LoadingState: View {
    var message = "読み込み中…"
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 16) {
            Image("Emblem")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .opacity(pulse ? 1.0 : 0.4)
                .scaleEffect(pulse ? 1.0 : 0.92)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .onAppear { pulse = true }
    }
}

// MARK: - 空状態（マスコット + メッセージ）

struct EmptyState: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.orange.opacity(0.7))
            } else {
                Image("Character")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 120)
                    .opacity(0.85)
            }
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}
