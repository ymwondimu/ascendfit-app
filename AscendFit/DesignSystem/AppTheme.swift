import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(
        light: UIColor(red: 242 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1),
        dark: UIColor(red: 11 / 255, green: 11 / 255, blue: 15 / 255, alpha: 1)
    )
    static let surfacePrimary = Color(
        light: .white,
        dark: UIColor(red: 21 / 255, green: 21 / 255, blue: 27 / 255, alpha: 1)
    )
    static let surfaceSecondary = Color(
        light: UIColor(red: 232 / 255, green: 230 / 255, blue: 238 / 255, alpha: 1),
        dark: UIColor(red: 32 / 255, green: 31 / 255, blue: 39 / 255, alpha: 1)
    )
    static let surfaceTertiary = Color(
        light: UIColor(red: 218 / 255, green: 215 / 255, blue: 226 / 255, alpha: 1),
        dark: UIColor(red: 42 / 255, green: 41 / 255, blue: 50 / 255, alpha: 1)
    )
    static let contentPrimary = Color(
        light: UIColor(red: 24 / 255, green: 22 / 255, blue: 31 / 255, alpha: 1),
        dark: UIColor(red: 240 / 255, green: 238 / 255, blue: 245 / 255, alpha: 1)
    )
    static let contentSecondary = Color(
        light: UIColor(red: 24 / 255, green: 22 / 255, blue: 31 / 255, alpha: 0.62),
        dark: UIColor(red: 240 / 255, green: 238 / 255, blue: 245 / 255, alpha: 0.62)
    )
    static let contentTertiary = Color(
        light: UIColor(red: 24 / 255, green: 22 / 255, blue: 31 / 255, alpha: 0.42),
        dark: UIColor(red: 240 / 255, green: 238 / 255, blue: 245 / 255, alpha: 0.40)
    )
    static let accent = Color(red: 183 / 255, green: 164 / 255, blue: 255 / 255)
    static let accentContent = Color(
        light: UIColor(red: 106 / 255, green: 79 / 255, blue: 214 / 255, alpha: 1),
        dark: UIColor(red: 183 / 255, green: 164 / 255, blue: 255 / 255, alpha: 1)
    )
    static let onAccent = Color(red: 20 / 255, green: 15 / 255, blue: 42 / 255)

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 28
        static let screenInset: CGFloat = 20
    }
}

private extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var fontSize = 19.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? AppTheme.onAccent : AppTheme.contentSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(isEnabled ? AppTheme.accent : AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18))
            .scaleEffect(configuration.isPressed && !reduceMotion && isEnabled ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var fontSize = 17.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? AppTheme.contentPrimary : AppTheme.contentSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(AppTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
