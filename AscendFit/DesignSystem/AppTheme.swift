import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(
        light: UIColor(red: 243 / 255, green: 244 / 255, blue: 239 / 255, alpha: 1),
        dark: UIColor(red: 9 / 255, green: 14 / 255, blue: 18 / 255, alpha: 1)
    )
    static let surfacePrimary = Color(
        light: .white,
        dark: UIColor(red: 22 / 255, green: 28 / 255, blue: 33 / 255, alpha: 1)
    )
    static let surfaceSecondary = Color(
        light: UIColor(red: 232 / 255, green: 233 / 255, blue: 228 / 255, alpha: 1),
        dark: UIColor(red: 35 / 255, green: 40 / 255, blue: 47 / 255, alpha: 1)
    )
    static let surfaceTertiary = Color(
        light: UIColor(red: 218 / 255, green: 220 / 255, blue: 216 / 255, alpha: 1),
        dark: UIColor(red: 49 / 255, green: 52 / 255, blue: 61 / 255, alpha: 1)
    )
    static let contentPrimary = Color(
        light: UIColor(red: 17 / 255, green: 23 / 255, blue: 27 / 255, alpha: 1),
        dark: UIColor(red: 247 / 255, green: 248 / 255, blue: 244 / 255, alpha: 1)
    )
    static let contentSecondary = Color(
        light: UIColor(red: 17 / 255, green: 23 / 255, blue: 27 / 255, alpha: 0.66),
        dark: UIColor(red: 247 / 255, green: 248 / 255, blue: 244 / 255, alpha: 0.68)
    )
    static let contentTertiary = Color(
        light: UIColor(red: 17 / 255, green: 23 / 255, blue: 27 / 255, alpha: 0.47),
        dark: UIColor(red: 247 / 255, green: 248 / 255, blue: 244 / 255, alpha: 0.46)
    )
    static let accent = Color(red: 188 / 255, green: 169 / 255, blue: 255 / 255)
    static let accentContent = Color(
        light: UIColor(red: 96 / 255, green: 67 / 255, blue: 179 / 255, alpha: 1),
        dark: UIColor(red: 188 / 255, green: 169 / 255, blue: 255 / 255, alpha: 1)
    )
    static let action = Color(red: 219 / 255, green: 241 / 255, blue: 101 / 255)
    static let actionHighlight = Color(red: 239 / 255, green: 249 / 255, blue: 153 / 255)
    static let onAccent = Color(red: 19 / 255, green: 25 / 255, blue: 13 / 255)

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
            .font(.system(size: fontSize, weight: .semibold, design: .default))
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? AppTheme.onAccent : AppTheme.contentSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isEnabled
                          ? LinearGradient(colors: [AppTheme.actionHighlight, AppTheme.action], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [AppTheme.surfaceSecondary], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.white.opacity(isEnabled ? 0.16 : 0), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(isEnabled ? (configuration.isPressed ? 0.10 : 0.20) : 0), radius: configuration.isPressed ? 4 : 9, y: configuration.isPressed ? 2 : 5)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion && isEnabled ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var fontSize = 17.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .padding(.vertical, 12)
            .foregroundStyle(isEnabled ? AppTheme.contentPrimary : AppTheme.contentSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(AppTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

struct CompactStepperButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 42, height: 42)
            .background {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.surfaceTertiary, AppTheme.surfaceSecondary], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.20), radius: configuration.isPressed ? 2 : 5, y: configuration.isPressed ? 1 : 3)
            }
            .frame(minWidth: 56, minHeight: 56)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CampaignScreenIntro: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.action)
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .default))
                .tracking(-0.8)
                .foregroundStyle(AppTheme.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.contentSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }
}
