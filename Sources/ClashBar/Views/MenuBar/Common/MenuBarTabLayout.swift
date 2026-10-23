import SwiftUI

struct MenuBarTabMetrics: Equatable {
    var headerHeight: CGFloat = 0
    var contentHeight: CGFloat = 0
}

struct MenuBarTabMetricsKey: PreferenceKey {
    static var defaultValue: MenuBarTabMetrics { MenuBarTabMetrics() }

    static func reduce(value: inout MenuBarTabMetrics, nextValue: () -> MenuBarTabMetrics) {
        let next = nextValue()
        value.headerHeight = max(value.headerHeight, next.headerHeight)
        value.contentHeight = max(value.contentHeight, next.contentHeight)
    }
}

struct MenuBarTabLayout<Header: View, Content: View>: View {
    private let spacing: CGFloat
    private let header: Header
    private let content: Content

    init(
        spacing: CGFloat = MenuBarLayoutTokens.space6,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content)
    {
        self.spacing = spacing
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: self.spacing) {
            self.header
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: MenuBarTabMetricsKey.self,
                            value: MenuBarTabMetrics(headerHeight: geometry.size.height + self.spacing))
                    }
                }

            ScrollView(.vertical) {
                self.content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: MenuBarTabMetricsKey.self,
                                value: MenuBarTabMetrics(contentHeight: max(1, geometry.size.height)))
                        }
                    }
            }
            // Override macOS mouse and scrollbar preferences, including after tab recreation.
            // 覆盖 macOS 鼠标与滚动条偏好，切页重建后也不出现占位轨道。
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
