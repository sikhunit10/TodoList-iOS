//
//  ColorExtensions.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI

// MARK: - AppTheme

/// Central theme management for the app
struct AppTheme {
    // MARK: - Colors
    
    // App accent color
    static let accentColor = Color(hex: "#5D4EFF")
    
    // Task priorities
    static let taskPriorityLow = Color(hex: "#3478F6")
    static let taskPriorityMedium = Color(hex: "#FF9F0A")
    static let taskPriorityHigh = Color(hex: "#FF453A")
    
    // Default category color
    static let defaultCategoryColor = Color(hex: "#007AFF")
    
    // UI Constants
    struct UI {
        // Animations
        static let standardAnimationDuration = 0.2
        static let springResponse = 0.3
        static let springDamping = 0.7
        
        // Durations
        static let dueSoonThresholdDays = 3
        
        // Dimensions
        static let cardHeight = 98.0 // Taller to accommodate vertical footer and larger category badge
        static let cardHeightWithDescription = 138.0 // Taller to accommodate vertical footer and larger category badge
        static let categoryBadgeWidth = 95.0 // Wider to fit "Uncategorized" text
        static let floatingButtonSize = 62.0
        static let filterIndicatorWidth = 40.0
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