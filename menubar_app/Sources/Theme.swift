import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Primary
    static let xpPrimary = Color(hex: 0x005CC0)
    static let xpPrimaryContainer = Color(hex: 0x3784F7)
    static let xpOnPrimary = Color.white

    // Surfaces
    static let xpSurface = Color(hex: 0xF8F9FA)
    static let xpSurfaceDim = Color(hex: 0xECEFF1)
    static let xpSurfaceContainerLowest = Color(hex: 0xFFFFFF)
    static let xpSurfaceContainerLow = Color(hex: 0xF1F4F5)
    static let xpSurfaceContainerHigh = Color(hex: 0xE4E8EA)
    static let xpSurfaceContainerHighest = Color(hex: 0xD7DCDE)

    // Text
    static let xpOnSurface = Color(hex: 0x2D3335)
    static let xpOnSurfaceVariant = Color(hex: 0x6B7578)

    // Utility
    static let xpOutlineVariant = Color(hex: 0xC4CACC)
    static let xpTertiary = Color(hex: 0x685781)
    static let xpInverseSurface = Color(hex: 0x0C0F10)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Typography

struct XPFont {
    static func displayMd() -> Font {
        .system(size: 28, weight: .semibold, design: .default)
    }

    static func headlineLg() -> Font {
        .system(size: 22, weight: .semibold, design: .default)
    }

    static func titleLg() -> Font {
        .system(size: 22, weight: .medium, design: .default)
    }

    static func titleMd() -> Font {
        .system(size: 17, weight: .medium, design: .default)
    }

    static func bodyMd() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    static func bodySm() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static func labelMd() -> Font {
        .system(size: 12, weight: .semibold, design: .default)
    }

    static func labelSm() -> Font {
        .system(size: 11, weight: .medium, design: .default)
    }
}

// MARK: - Spacing

struct XPSpacing {
    static let s1: CGFloat = 0.25 * 16  // 4
    static let s2: CGFloat = 0.5 * 16   // 8
    static let s3: CGFloat = 0.75 * 16  // 12
    static let s4: CGFloat = 1.0 * 16   // 16
    static let s5: CGFloat = 1.25 * 16  // 20
    static let s6: CGFloat = 1.5 * 16   // 24
    static let s8: CGFloat = 2.0 * 16   // 32
}

// MARK: - Roundedness

struct XPRadius {
    static let sm: CGFloat = 2
    static let md: CGFloat = 6
    static let lg: CGFloat = 10
    static let xl: CGFloat = 12
}

// MARK: - Shadows

extension View {
    func xpAmbientShadow() -> some View {
        self.shadow(color: Color(hex: 0x0C0F10, opacity: 0.06), radius: 20, x: 0, y: 6)
    }

    func xpGhostBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: XPRadius.xl)
                .stroke(Color.xpOutlineVariant.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Button Styles

struct XPPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XPFont.bodyMd())
            .fontWeight(.medium)
            .foregroundColor(.xpOnPrimary)
            .padding(.horizontal, XPSpacing.s4)
            .padding(.vertical, XPSpacing.s2)
            .background(
                LinearGradient(
                    colors: [.xpPrimary, .xpPrimaryContainer],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: XPRadius.xl))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct XPSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XPFont.bodySm())
            .fontWeight(.medium)
            .foregroundColor(.xpOnSurface)
            .padding(.horizontal, XPSpacing.s3)
            .padding(.vertical, XPSpacing.s1 + 2)
            .background(Color.xpSurfaceContainerHighest)
            .clipShape(RoundedRectangle(cornerRadius: XPRadius.md))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct XPTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XPFont.bodySm())
            .fontWeight(.medium)
            .foregroundColor(.xpPrimary)
            .padding(.horizontal, XPSpacing.s3)
            .padding(.vertical, XPSpacing.s1 + 2)
            .background(configuration.isPressed ? Color.xpSurfaceContainerLow : .clear)
            .clipShape(RoundedRectangle(cornerRadius: XPRadius.md))
    }
}

// MARK: - Category Header

struct XPCategoryHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(XPFont.labelMd())
            .tracking(0.8)
            .foregroundColor(.xpOnSurfaceVariant)
            .padding(.top, XPSpacing.s4)
            .padding(.bottom, XPSpacing.s2)
    }
}
