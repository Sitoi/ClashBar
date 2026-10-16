import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct TrafficStatisticsView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var connectionsStore: ConnectionsStore

    var body: some View {
        let snapshot = self.connectionsStore.statistics
        let entries = snapshot.dimension == self.connectionsStore.statisticsDimension ? snapshot.entries : []

        return VStack(alignment: .leading, spacing: T.space6) {
            self.tabControlCard {
                Picker(self.tr("ui.statistics.title"), selection: self.$connectionsStore.statisticsDimension) {
                    ForEach(TrafficStatisticsDimension.allCases, id: \.self) { dimension in
                        Text(self.tr(dimension.titleKey)).tag(dimension)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack(spacing: T.space4) {
                    Text(self.tr("ui.statistics.session"))
                    Image(systemName: "info.circle")
                        .help(self.tr("ui.statistics.sampling_hint"))
                }
                .font(.app(size: T.FontSize.caption, weight: .regular))
                .foregroundStyle(nativeTertiaryLabel)
                .padding(.top, T.space2)
            }

            if entries.isEmpty {
                emptyCard(self.tr("ui.statistics.empty"))
            } else {
                LazyVStack(spacing: 0) {
                    SeparatedForEach(data: entries, id: \.id, separator: nativeSeparator) { entry in
                        self.statisticsRow(entry)
                    }
                }
            }
        }
    }

    private func statisticsRow(_ entry: TrafficStatisticsEntry) -> some View {
        let name = entry.name.isEmpty ? self.tr("ui.statistics.unknown") : entry.name

        return VStack(alignment: .leading, spacing: T.space2) {
            HStack(spacing: T.space6) {
                Text(name)
                    .font(.app(size: T.FontSize.body, weight: .semibold))
                    .foregroundStyle(nativePrimaryLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: T.space4) {
                    Text(self.tr("ui.statistics.total"))
                        .foregroundStyle(nativeTertiaryLabel)
                    Text(ValueFormatter.bytesCompactNoSpace(entry.total))
                        .foregroundStyle(nativePrimaryLabel)
                        .monospacedDigit()
                }
                .font(.app(size: T.FontSize.caption, weight: .medium))
                .fixedSize()
            }

            HStack(spacing: T.space8) {
                Label(ValueFormatter.bytesCompactNoSpace(entry.upload), systemImage: "arrow.up")
                    .foregroundStyle(nativeInfo.opacity(T.Opacity.solid))
                Label(ValueFormatter.bytesCompactNoSpace(entry.download), systemImage: "arrow.down")
                    .foregroundStyle(nativePositive.opacity(T.Opacity.solid))
            }
            .font(.app(size: T.FontSize.caption, weight: .medium))
            .monospacedDigit()
        }
        .padding(.horizontal, T.space4)
        .padding(.vertical, T.space4)
        .help(name)
    }
}
