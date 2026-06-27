//
//  MoreAppsPromoView.swift
//  MouseMe
//

import SwiftUI

enum MoreAppsPromoStyle {
    case list
    case cards
    case panel
}

struct MoreAppsPromoView: View {
    var style: MoreAppsPromoStyle = .list
    var apps: [DeveloperApp] = DeveloperApps.promoted

    var body: some View {
        switch style {
        case .list:
            listContent
        case .cards:
            cardsContent
        case .panel:
            panelContent
        }
    }

    // MARK: - iOS Settings / Connect list rows

    private var listContent: some View {
        ForEach(apps) { app in
            Button {
                AppStoreOpener.open(app)
            } label: {
                HStack(spacing: 14) {
                    appIcon(app, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.foreground)
                        Text(app.tagline)
                            .font(.caption)
                            .foregroundStyle(AppTheme.labelTertiary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Text("Get")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.accent))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Horizontal scroll cards (optional compact promo)

    private var cardsContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(apps) { app in
                    promoCard(app)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - macOS receiver panel

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(apps) { app in
                panelRow(app)
            }
        }
    }

    private func promoCard(_ app: DeveloperApp) -> some View {
        Button {
            AppStoreOpener.open(app)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                appIcon(app, size: 44)
                Text(app.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.foreground)
                Text(app.tagline)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.labelTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("View on App Store")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(app.tint)
            }
            .frame(width: 168, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(app.tint.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func panelRow(_ app: DeveloperApp) -> some View {
        Button {
            AppStoreOpener.open(app)
        } label: {
            HStack(spacing: 12) {
                appIcon(app, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.callout.bold())
                    Text(app.tagline)
                        .font(.caption)
                        .foregroundStyle(AppTheme.labelTertiary)
                        .lineLimit(2)
                }
                Spacer()
                Text("Get")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(app.tint.opacity(0.18)))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func appIcon(_ app: DeveloperApp, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [app.tint.opacity(0.85), app.tint.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: app.symbolName)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

#Preview("List") {
    List {
        Section("More from Ryan") {
            MoreAppsPromoView(style: .list)
        }
    }
}

#Preview("Cards") {
    MoreAppsPromoView(style: .cards)
        .padding()
}
