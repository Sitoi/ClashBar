import SwiftUI

extension MenuBarRoot {
    var topHeader: some View {
        HStack(alignment: .center, spacing: MenuBarLayoutTokens.space8) {
            HStack(alignment: .center, spacing: MenuBarLayoutTokens.space8) {
                ZStack {
                    RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                        .fill(nativeControlFill.opacity(MenuBarLayoutTokens.Opacity.solid))
                        .overlay {
                            RoundedRectangle(cornerRadius: MenuBarLayoutTokens.cornerRadius, style: .continuous)
                                .stroke(
                                    nativeControlBorder.opacity(MenuBarLayoutTokens.Opacity.solid),
                                    lineWidth: MenuBarLayoutTokens.stroke)
                        }

                    if let brandImage = BrandIcon.image {
                        Image(nsImage: brandImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: MenuBarLayoutTokens.rowHeight, height: MenuBarLayoutTokens.rowHeight)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .renderingMode(.template)
                            .symbolRenderingMode(.monochrome)
                            .resizable()
                            .scaledToFit()
                            .frame(width: MenuBarLayoutTokens.rowHeight, height: MenuBarLayoutTokens.rowHeight)
                            .foregroundStyle(nativeAccent)
                    }
                }
                .frame(width: MenuBarLayoutTokens.rowHeight, height: MenuBarLayoutTokens.rowHeight)

                VStack(alignment: .leading, spacing: MenuBarLayoutTokens.space4) {
                    HStack(spacing: MenuBarLayoutTokens.space6) {
                        Text("ClashBar")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.title, weight: .semibold))
                            .foregroundStyle(nativePrimaryLabel)

                        HStack(spacing: MenuBarLayoutTokens.space1) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: MenuBarLayoutTokens.space6, height: MenuBarLayoutTokens.space6)
                            Text(runtimeBadgeText)
                                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                                .foregroundStyle(nativeSecondaryLabel)
                        }
                        .padding(.horizontal, MenuBarLayoutTokens.space6)
                        .padding(.vertical, MenuBarLayoutTokens.space2)
                        .background(nativeControlFill.opacity(MenuBarLayoutTokens.Opacity.solid), in: Capsule())
                        .overlay {
                            Capsule().stroke(
                                nativeControlBorder.opacity(
                                    isDarkAppearance
                                        ? MenuBarLayoutTokens.Theme.Dark.borderEmphasis
                                        : MenuBarLayoutTokens.Theme.Light.borderEmphasis),
                                lineWidth: MenuBarLayoutTokens.stroke)
                        }
                    }

                    HStack(spacing: MenuBarLayoutTokens.space6) {
                        if appState.isRemoteTarget {
                            self.remoteConnectionStatusDot
                        }
                        self.headerControllerLink(
                            symbol: "network",
                            text: appState.externalControllerDisplay)
                        if appState.isExternalControllerWildcardIPv4 {
                            self.headerControllerWarningIcon
                        }
                        if appState.isRemoteTarget {
                            self.remoteConnectionStatusLabel
                        }
                    }
                }
            }

            Spacer(minLength: MenuBarLayoutTokens.space6)

            HStack(spacing: MenuBarLayoutTokens.space6) {
                self.compactTopIcon(
                    "arrow.clockwise",
                    label: appState.primaryCoreActionLabel,
                    toneOverride: nativeInfo)
                {
                    await appState.performPrimaryCoreAction()
                }
                .disabled(appState.isRemoteTarget || !appState.isPrimaryCoreActionEnabled)
                .opacity((appState.isRemoteTarget || !appState.isPrimaryCoreActionEnabled) ? 0.6 : 1)

                self.compactTopIcon(
                    appState.isRuntimeRunning ? "stop.circle" : "play.circle",
                    label: appState.isRuntimeRunning ? tr("ui.action.stop") : tr("app.primary.start"),
                    toneOverride: appState.isRuntimeRunning ? nativeWarning : nativePositive)
                {
                    if appState.isRuntimeRunning {
                        await appState.stopCore()
                    } else {
                        await appState.startCore(trigger: .manual)
                    }
                }
                .disabled(appState.isRemoteTarget || appState.isCoreActionProcessing)
                .opacity((appState.isRemoteTarget || appState.isCoreActionProcessing) ? 0.6 : 1)

                self.compactTopIcon("power", label: tr("ui.action.quit"), warning: true) {
                    await appState.quitApp()
                }
            }
        }
        .padding(.vertical, MenuBarLayoutTokens.space8)
    }

    func headerMetaLabel(symbol: String, text: String) -> some View {
        HStack(spacing: MenuBarLayoutTokens.space4) {
            Image(systemName: symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(nativeTertiaryLabel)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
        .foregroundStyle(nativeSecondaryLabel)
    }

    @ViewBuilder
    func headerControllerLink(symbol: String, text: String) -> some View {
        if let url = makeMetaCubeXDSetupURL(
            controller: appState.controller,
            secret: appState.controllerSecret)
        {
            Link(destination: url) {
                self.headerMetaLabel(symbol: symbol, text: text)
            }
            .buttonStyle(.plain)
            .help(url.absoluteString)
        } else {
            self.headerMetaLabel(symbol: symbol, text: text)
        }
    }

    @ViewBuilder
    var remoteConnectionStatusDot: some View {
        let status = self.activeRemoteConnectionStatus
        Circle()
            .fill(self.remoteStatusDotColor(status))
            .frame(width: MenuBarLayoutTokens.space6, height: MenuBarLayoutTokens.space6)
    }

    @ViewBuilder
    var remoteConnectionStatusLabel: some View {
        let status = self.activeRemoteConnectionStatus
        switch status {
        case .unknown, .checking:
            ProgressView()
                .controlSize(.mini)
        case let .connected(version):
            Text(version)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(nativePositive)
                .lineLimit(1)
        case let .failed(reason):
            Text(reason)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .medium))
                .foregroundStyle(nativeCritical)
                .lineLimit(1)
        }
    }

    var activeRemoteConnectionStatus: MachineConnectionStatus {
        guard let activeID = remoteMachineStore.activeTargetID else { return .unknown }
        let probeStatus = remoteMachineStore.statusFor(activeID)

        switch appState.apiStatus {
        case .healthy:
            if case let .connected(version) = probeStatus {
                return .connected(version: version)
            }
            let runtimeVersion = appState.version.trimmed
            if !runtimeVersion.isEmpty, runtimeVersion != "-" {
                return .connected(version: runtimeVersion)
            }
            return .connected(version: "OK")
        case .degraded:
            if case let .failed(reason) = probeStatus {
                return .failed(reason: reason)
            }
            return .checking
        case .unknown:
            return probeStatus
        case .failed:
            if case let .failed(reason) = probeStatus {
                return .failed(reason: reason)
            }
            return .failed(reason: tr("ui.machine.status_unreachable"))
        }
    }

    func remoteStatusDotColor(_ status: MachineConnectionStatus) -> Color {
        switch status {
        case .unknown: nativeSecondaryLabel
        case .checking: nativeWarning.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .connected: nativePositive.opacity(MenuBarLayoutTokens.Opacity.solid)
        case .failed: nativeCritical.opacity(MenuBarLayoutTokens.Opacity.solid)
        }
    }

    var headerControllerWarningIcon: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
            .foregroundStyle(nativeWarning)
            .help("external-controller is 0.0.0.0 and can be accessed from your LAN.")
            .accessibilityLabel("Warning: external-controller is bound to 0.0.0.0")
    }

    func makeMetaCubeXDSetupURL(controller: String, secret: String?) -> URL? {
        guard let endpoint = parseControllerEndpoint(controller) else { return nil }

        var query = URLComponents()
        var items: [URLQueryItem] = [
            URLQueryItem(name: "hostname", value: endpoint.host),
            URLQueryItem(name: "port", value: "\(endpoint.port)"),
            URLQueryItem(name: "http", value: endpoint.useHTTP ? "true" : "false"),
        ]
        if let trimmedSecret = secret.trimmedNonEmpty {
            items.append(URLQueryItem(name: "secret", value: trimmedSecret))
        }
        query.queryItems = items

        guard let encodedQuery = query.percentEncodedQuery else { return nil }
        return URL(string: "https://metacubexd.pages.dev/#/setup?\(encodedQuery)")
    }

    func parseControllerEndpoint(_ raw: String) -> (host: String, port: Int, useHTTP: Bool)? {
        let trimmed = raw.trimmed
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host,
              !host.isEmpty
        else {
            return nil
        }

        let scheme = components.scheme?.lowercased() ?? "http"
        let useHTTP = scheme != "https"
        let fallbackPort = useHTTP ? 80 : 443
        return (host: host, port: components.port ?? fallbackPort, useHTTP: useHTTP)
    }

    func compactTopIcon(
        _ symbol: String,
        label: String,
        role: ButtonRole? = nil,
        warning: Bool = false,
        toneOverride: Color? = nil,
        isLoading: Bool = false,
        action: @escaping () async -> Void) -> some View
    {
        let tone: Color = if let toneOverride {
            toneOverride
        } else if warning {
            nativeCritical
        } else {
            nativeSecondaryLabel
        }

        return self.compactAsyncIconButton(
            symbol: symbol,
            label: label,
            tint: tone.opacity(MenuBarLayoutTokens.Opacity.solid),
            role: role,
            isLoading: isLoading,
            action: action)
    }
}
