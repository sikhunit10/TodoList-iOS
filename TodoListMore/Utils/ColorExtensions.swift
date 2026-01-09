//
//  ColorExtensions.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI

// MARK: - AppTheme

/// Modern, comprehensive theme management for the app
struct AppTheme {
    // MARK: - Colors

    // Primary gradient colors for modern look
    static let primaryGradientStart = Color(hex: "#667EEA")
    static let primaryGradientEnd = Color(hex: "#764BA2")

    // App accent colors - enhanced with gradient support
    static let accentColor = Color(hex: "#667EEA")
    static let accentColorDark = Color(hex: "#5568D3")

    // Secondary accent for variety
    static let secondaryAccent = Color(hex: "#F093FB")
    static let secondaryAccentDark = Color(hex: "#F5576C")

    // Task priority colors - more vibrant and modern
    static let taskPriorityLow = Color(hex: "#4FD1C5")
    static let taskPriorityMedium = Color(hex: "#F6AD55")
    static let taskPriorityHigh = Color(hex: "#FC8181")

    // Enhanced gradient combinations for priorities
    static let lowPriorityGradient = [Color(hex: "#4FD1C5"), Color(hex: "#38B2AC")]
    static let mediumPriorityGradient = [Color(hex: "#F6AD55"), Color(hex: "#ED8936")]
    static let highPriorityGradient = [Color(hex: "#FC8181"), Color(hex: "#F56565")]

    // Background colors
    static let cardBackground = Color(hex: "#FFFFFF")
    static let cardBackgroundDark = Color(hex: "#2D3748")
    static let appBackground = Color(hex: "#F7FAFC")
    static let appBackgroundDark = Color(hex: "#1A202C")

    // Text colors
    static let primaryText = Color(hex: "#2D3748")
    static let secondaryText = Color(hex: "#718096")
    static let tertiaryText = Color(hex: "#A0AEC0")

    // Border and shadow
    static let borderColor = Color(hex: "#E2E8F0")
    static let shadowColor = Color.black.opacity(0.08)

    // Success, warning, error
    static let successColor = Color(hex: "#48BB78")
    static let warningColor = Color(hex: "#ED8936")
    static let errorColor = Color(hex: "#F56565")

    // Default category color
    static let defaultCategoryColor = Color(hex: "#667EEA")

    // MARK: - Gradients
    struct Gradients {
        static let primary = LinearGradient(
            colors: [primaryGradientStart, primaryGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let secondary = LinearGradient(
            colors: [secondaryAccent, secondaryAccentDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let success = LinearGradient(
            colors: [Color(hex: "#48BB78"), Color(hex: "#38A169")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let card = LinearGradient(
            colors: [Color.white, Color(hex: "#F7FAFC")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography
    struct Typography {
        // Font sizes
        static let largeTitle: CGFloat = 34
        static let title1: CGFloat = 28
        static let title2: CGFloat = 22
        static let title3: CGFloat = 20
        static let headline: CGFloat = 17
        static let body: CGFloat = 17
        static let callout: CGFloat = 16
        static let subheadline: CGFloat = 15
        static let footnote: CGFloat = 13
        static let caption1: CGFloat = 12
        static let caption2: CGFloat = 11

        // Font weights
        enum Weight {
            static let ultraLight = Font.Weight.ultraLight
            static let thin = Font.Weight.thin
            static let light = Font.Weight.light
            static let regular = Font.Weight.regular
            static let medium = Font.Weight.medium
            static let semibold = Font.Weight.semibold
            static let bold = Font.Weight.bold
            static let heavy = Font.Weight.heavy
            static let black = Font.Weight.black
        }
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows
    struct Shadow {
        static let small = (color: Color.black.opacity(0.05), radius: 4.0, x: 0.0, y: 2.0)
        static let medium = (color: Color.black.opacity(0.1), radius: 8.0, x: 0.0, y: 4.0)
        static let large = (color: Color.black.opacity(0.15), radius: 16.0, x: 0.0, y: 8.0)
        static let card = (color: Color.black.opacity(0.08), radius: 12.0, x: 0.0, y: 4.0)
    }

    // MARK: - UI Constants
    struct UI {
        // Animations
        static let standardAnimationDuration = 0.3
        static let springResponse = 0.35
        static let springDamping = 0.75

        // Spring animation preset
        static let springAnimation = Animation.spring(
            response: springResponse,
            dampingFraction: springDamping
        )

        // Durations
        static let dueSoonThresholdDays = 3

        // Dimensions - enhanced for modern look
        static let cardHeight = 110.0
        static let cardHeightWithDescription = 160.0
        static let categoryBadgeWidth = 95.0
        static let floatingButtonSize = 64.0
        static let filterIndicatorWidth = 40.0

        // Modern card styling
        static let cardPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 12
    }
}

extension Color {
    /// Creates a Color from a hex string (e.g. "#FF0000" for red)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Validate hex code format and return if valid
    static func isValidHex(_ hex: String) -> Bool {
        let hexRegex = "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"
        guard let regex = try? NSRegularExpression(pattern: hexRegex, options: []) else {
            return false
        }
        let range = NSRange(location: 0, length: hex.utf16.count)
        return regex.firstMatch(in: hex, options: [], range: range) != nil
    }
}