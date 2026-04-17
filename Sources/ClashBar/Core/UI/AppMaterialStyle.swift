import SwiftUI

enum AppSurfaceFallbackStyle {
    case material(Material)
    case color(Color)
}

struct AppMaterialSurface: View {
    let cornerRadius: CGFloat
    let fallbackStyle: AppSurfaceFallbackStyle
    let stroke: Color
    var lineWidth: CGFloat = MenuBarLayoutTokens.stroke

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)

        self.legacySurface(shape: shape)
            .overlay {
                shape.stroke(self.stroke, lineWidth: self.lineWidth)
            }
    }

    @ViewBuilder
    private func legacySurface(shape: RoundedRectangle) -> some View {
        switch self.fallbackStyle {
        case let .material(material):
            shape.fill(material)
        case let .color(color):
            shape.fill(color)
        }
    }
}

extension View {
    func appBorderedButtonStyle(prominent: Bool = false) -> some View {
        self.appLegacyBorderedButtonStyle(prominent: prominent)
    }

    @ViewBuilder
    private func appLegacyBorderedButtonStyle(prominent: Bool) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

/// Provides `language`, `tr(_:)`, and `tr(_:_:)` to any SwiftUI view owning an `appViewModel`.
/// Eliminates the per-file boilerplate duplicated across all menu bar tab views.
protocol TranslatingView: View {
    var appViewModel: AppViewModel { get }
}

extension TranslatingView {
    var language: AppLanguage {
        appViewModel.uiLanguage
    }

    func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        L10n.t(key, language: self.language, args: args)
    }
}
