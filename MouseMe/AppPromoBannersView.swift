//
//  AppPromoBannersView.swift
//  MouseMe
//

import SwiftUI

/// Full-width tappable banner for one App Store app.
struct AppPromoBannerRow: View {
    let app: DeveloperApp

    var body: some View {
        Button {
            AppStoreOpener.open(app)
        } label: {
            HStack(spacing: 14) {
                AppPromoIcon(app: app, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.labelPrimary)
                    Text(app.tagline)
                        .font(.caption)
                        .foregroundStyle(AppTheme.labelSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                VStack(spacing: 2) {
                    Text("Get")
                        .font(.caption.weight(.bold))
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(app.tint, in: Capsule())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.card, app.tint.opacity(0.14)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(app.tint.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Get \(app.name) on the App Store")
    }
}

/// Stack of all developer app banners — use at the bottom of each tab.
struct AppPromoBannersView: View {
    var apps: [DeveloperApp] = DeveloperApps.promoted
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeader {
                Label("More from Ryan", systemImage: "square.grid.2x2.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.labelSecondary)
            }
            ForEach(apps) { app in
                AppPromoBannerRow(app: app)
            }
        }
    }
}

struct AppPromoIcon: View {
    let app: DeveloperApp
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [app.tint.opacity(0.9), app.tint.opacity(0.5)],
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

#Preview {
    ScrollView {
        AppPromoBannersView()
            .padding()
    }
    .appScreenBackground()
    .preferredColorScheme(.dark)
}
