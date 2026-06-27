//
//  AppTheme.swift
//  MouseMe
//

import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.07, green: 0.08, blue: 0.11)
    static let background = Color(red: 0.05, green: 0.06, blue: 0.09)
    static let card = Color(red: 0.13, green: 0.14, blue: 0.19)
    static let cardRaised = Color(red: 0.17, green: 0.18, blue: 0.24)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let accent = Color(red: 0.38, green: 0.58, blue: 1.0)
    static let border = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.16)
    static let labelSecondary = Color(red: 0.76, green: 0.78, blue: 0.84)
    static let labelTertiary = Color(red: 0.58, green: 0.61, blue: 0.68)
    static let success = Color(red: 0.28, green: 0.82, blue: 0.52)
    static let warning = Color(red: 1.0, green: 0.70, blue: 0.26)

    static var screenGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func cardBackground(cornerRadius: CGFloat = 16) -> some ShapeStyle {
        card
    }
}

extension View {
    func appScreenBackground() -> some View {
        background(AppTheme.screenGradient.ignoresSafeArea())
    }

    func appDarkListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.screenGradient.ignoresSafeArea())
    }

    func appCard(radius: CGFloat = 16, raised: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(raised ? AppTheme.cardRaised : AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

struct AppSectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(AppTheme.labelSecondary)
            .textCase(nil)
    }
}

extension View {
    func appSectionHeader() -> some View {
        modifier(AppSectionHeader())
    }
}
