import Foundation

struct ResolveOverlayPortFieldsUseCase {
    func execute(
        overlay: EditableSettingsSnapshot,
        fallback: EditableSettingsSnapshot?) -> [SettingsPortField]
    {
        [
            SettingsPortField(
                key: "port",
                value: self.resolvedOverlayPortValue(overlay.port, fallback: fallback?.port ?? "")),
            SettingsPortField(
                key: "socks-port",
                value: self.resolvedOverlayPortValue(overlay.socksPort, fallback: fallback?.socksPort ?? "")),
            SettingsPortField(
                key: "mixed-port",
                value: self.resolvedOverlayPortValue(overlay.mixedPort, fallback: fallback?.mixedPort ?? "")),
            SettingsPortField(
                key: "redir-port",
                value: self.resolvedOverlayPortValue(overlay.redirPort, fallback: fallback?.redirPort ?? "")),
            SettingsPortField(
                key: "tproxy-port",
                value: self.resolvedOverlayPortValue(overlay.tproxyPort, fallback: fallback?.tproxyPort ?? "")),
        ]
    }

    private func resolvedOverlayPortValue(_ overlayValue: String, fallback: String) -> String {
        overlayValue.trimmedNonEmpty ?? fallback.trimmed
    }
}
