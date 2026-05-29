import SwiftUI

@MainActor
struct TrailShotLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.43, blue: 0.84),
                            Color(red: 0.14, green: 0.68, blue: 0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            AstroMark()
                .stroke(.white, style: StrokeStyle(lineWidth: max(size * 0.07, 2), lineCap: .round, lineJoin: .round))
                .padding(size * 0.22)

            Circle()
                .fill(.white)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.10, y: -size * 0.02)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("TrailShot")
    }
}

private struct AstroMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let head = CGRect(
            x: rect.minX + rect.width * 0.14,
            y: rect.minY + rect.height * 0.20,
            width: rect.width * 0.72,
            height: rect.height * 0.58
        )

        path.addRoundedRect(in: head, cornerSize: CGSize(width: rect.width * 0.28, height: rect.height * 0.28))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.08))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.90, y: rect.minY + rect.height * 0.08))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.16))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.16))

        return path
    }
}
