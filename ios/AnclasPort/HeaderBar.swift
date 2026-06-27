import SwiftUI

struct HeaderBar: View {
    let title: String

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Theme.orange, Theme.orange.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("Character")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 70)
                .opacity(0.18)
                .offset(x: 10, y: 8)
        }
        .frame(height: 90)
        .overlay(alignment: .leading) {
            HStack(spacing: 10) {
                Image("Emblem")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .shadow(radius: 3)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
    }
}
