import SwiftUI

extension Color {
    static let appBackground = Color(hex: "#131313")
    static let surfaceContainerLow = Color(hex: "#1b1b1c")
    static let surfaceContainer = Color(hex: "#202020")
    static let surfaceContainerHighest = Color(hex: "#353535")
    static let surfaceBright = Color(hex: "#393939")
    static let appPrimary = Color(hex: "#adc6ff")
    static let primaryContainer = Color(hex: "#4b8eff")
    static let onSurface = Color(hex: "#e5e2e1")
    static let onSurfaceVariant = Color(hex: "#c1c6d7")
    static let outlineVariant = Color(hex: "#414755").opacity(0.15)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [.primaryContainer, .appPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
