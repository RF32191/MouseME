//
//  AppTheme.swift
//  MouseMe
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    // Near-black surfaces — do not rely on system grouped backgrounds.
    static let backgroundTop = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let background = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let card = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let cardRaised = Color(red: 0.13, green: 0.14, blue: 0.18)
    static let surface = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let field = Color(red: 0.07, green: 0.08, blue: 0.11)
    static let accent = Color(red: 0.42, green: 0.62, blue: 1.0)
    static let border = Color.white.opacity(0.12)
    static let borderStrong = Color.white.opacity(0.20)
    static let labelPrimary = Color.white
    static let labelSecondary = Color(red: 0.86, green: 0.88, blue: 0.92)
    static let labelTertiary = Color(red: 0.62, green: 0.66, blue: 0.74)
    static let success = Color(red: 0.32, green: 0.88, blue: 0.58)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.28)

    static var screenGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, background],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#if canImport(UIKit)
enum AppThemeAppearance {
    static func configure() {
        let bg = UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        let card = UIColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1)
        let label = UIColor(red: 0.86, green: 0.88, blue: 0.92, alpha: 1)
        let muted = UIColor(red: 0.62, green: 0.66, blue: 0.74, alpha: 1)

        UITableView.appearance().backgroundColor = bg
        UITableViewCell.appearance().backgroundColor = card

        UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self]).textColor = muted

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bg
        nav.titleTextAttributes = [.foregroundColor: label]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.accent)

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        tab.stackedLayoutAppearance.normal.iconColor = muted
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: muted]
        tab.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.accent)
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.accent)]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        UITextField.appearance().backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1)
        UITextField.appearance().textColor = .white
    }
}
#endif

struct AppDarkFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body)
            .foregroundStyle(AppTheme.labelPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

struct AppSectionTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.labelSecondary)
            .textCase(nil)
    }
}

struct AppSectionFooterText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(AppTheme.labelTertiary)
    }
}

extension View {
    func appScreenBackground() -> some View {
        background(AppTheme.background.ignoresSafeArea())
    }

    /// Dark list/form chrome — plain style so iPad doesn't force white grouped cards.
    func appListChrome() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .listStyle(.plain)
            .listSectionSpacing(12)
            .listRowSeparatorTint(AppTheme.border)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.card)
                    .padding(.vertical, 2)
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .foregroundStyle(AppTheme.labelPrimary)
            .tint(AppTheme.accent)
    }

    func appDarkListStyle() -> some View {
        appListChrome()
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

    func appPageChrome() -> some View {
        preferredColorScheme(.dark)
            .colorScheme(.dark)
            .appScreenBackground()
            .toolbarBackground(AppTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
