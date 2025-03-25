//
//  ViewExtensions.swift
//  TodoListMore
//
//  Created by Harjot Singh on 24/03/25.
//

import SwiftUI

// Extension to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// Extension to make String identifiable for the sheet
extension String: Identifiable {
    public var id: String { self }
}

// Button style with bounce animation for better feedback
extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle {
        return ScaleButtonStyle()
    }
}