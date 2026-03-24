import SwiftUI

struct RemoteMachineManagerView: View {
    private enum EditorMode {
        case add
        case edit(RemoteMachine)

        var machine: RemoteMachine? {
            switch self {
            case .add:
                nil
            case let .edit(machine):
                machine
            }
        }
    }

    private enum RowAction: Hashable {
        case edit
        case delete

        var symbol: String {
            switch self {
            case .edit:
                "pencil"
            case .delete:
                "trash"
            }
        }

        var accessibilityKey: String {
            switch self {
            case .edit:
                "ui.machine.edit"
            case .delete:
                "ui.action.delete"
            }
        }

        var isDestructive: Bool {
            switch self {
            case .edit:
                false
            case .delete:
                true
            }
        }
    }

    private struct HoveredRowAction: Hashable {
        let machineID: UUID
        let action: RowAction
    }

    @ObservedObject var store: RemoteMachineStore
    let localControllerDisplay: String
    let onSwitchTarget: (MachineTarget) -> Void

    @State private var editorMode: EditorMode?
    @State private var hoveredMachineID: UUID?
    @State private var hoveredRowAction: HoveredRowAction?
    @State private var hoveringLocalCard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "clashbar.ui.language") ?? "") ?? .zhHans
    }

    private var panelWidth: CGFloat {
        MenuBarLayoutTokens.panelWidth
    }

    private var panelHeight: CGFloat {
        500
    }

    private var outerPadding: CGFloat {
        16
    }

    private var cardPadding: CGFloat {
        12
    }

    private var cardCornerRadius: CGFloat {
        12
    }

    private var trailingActionAreaWidth: CGFloat {
        66
    }

    private var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    private var panelBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    private var primaryTextColor: Color {
        Color(nsColor: .labelColor)
    }

    private var secondaryTextColor: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.labelSecondary : MenuBarLayoutTokens.Theme
                .Light.labelSecondary)
    }

    private var tertiaryTextColor: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.labelTertiary : MenuBarLayoutTokens.Theme
                .Light.labelTertiary)
    }

    private var borderColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? 0.22 : 0.10)
    }

    private var separatorColor: Color {
        Color(nsColor: .separatorColor)
            .opacity(self.isDarkAppearance ? MenuBarLayoutTokens.Theme.Dark.separator : MenuBarLayoutTokens.Theme.Light
                .separator)
    }

    private var cardFill: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.05)
        }
        return Color.white.opacity(0.42)
    }

    private var cardHoverFill: Color {
        if self.isDarkAppearance {
            return Color.white.opacity(0.10)
        }
        return Color.white.opacity(0.62)
    }

    private var cardSelectedFill: Color {
        self.accentTint.opacity(self.isDarkAppearance ? 0.14 : 0.10)
    }

    private var accentTint: Color {
        Color(nsColor: .controlAccentColor)
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isEditing: Bool {
        self.editorMode != nil
    }

    private var headerTitle: String {
        if let editorMode {
            switch editorMode {
            case .add:
                self.tr("ui.machine.add")
            case .edit:
                self.tr("ui.machine.edit")
            }
        } else {
            self.tr("ui.machine.manage")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.headerBar
            Group {
                if let editorMode {
                    self.editorContent(for: editorMode)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    self.listContent
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(self.outerPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: self.panelWidth, height: self.panelHeight, alignment: .topLeading)
        .background(self.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: MenuBarLayoutTokens.panelCornerRadius, style: .continuous))
        .animation(.snappy(duration: 0.18), value: self.isEditing)
        .onAppear {
            self.store.startPeriodicConnectivityChecks()
        }
        .onDisappear {
            self.store.stopPeriodicConnectivityChecks()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(self.accentTint.opacity(self.isDarkAppearance ? 0.22 : 0.14))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "network")
                            .font(.app(size: MenuBarLayoutTokens.FontSize.body, weight: .semibold))
                            .foregroundStyle(self.accentTint)
                    }

                Text(self.headerTitle)
                    .font(.app(size: 13, weight: .semibold))
                    .foregroundStyle(self.primaryTextColor)
            }

            Spacer(minLength: 0)

            Button {
                if self.isEditing {
                    self.editorMode = nil
                } else {
                    self.dismiss()
                }
            } label: {
                Image(systemName: self.isEditing ? "chevron.left" : "xmark")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                    .foregroundStyle(self.tertiaryTextColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.black.opacity(self.isDarkAppearance ? 0.18 : 0.04),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, self.outerPadding)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(self.separatorColor)
                .frame(height: MenuBarLayoutTokens.stroke)
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            self.machineCards
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            self.primaryActionButton(title: self.tr("ui.machine.add"), systemImage: "plus") {
                self.editorMode = .add
            }
        }
    }

    private var machineCards: some View {
        ScrollView {
            VStack(spacing: 10) {
                self.localCard
                ForEach(self.store.machines) { machine in
                    self.remoteCard(machine)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var localCard: some View {
        let isActive = self.store.activeTarget.isLocal
        let hovered = self.hoveringLocalCard

        return Button {
            guard !isActive else { return }
            self.onSwitchTarget(.local)
            self.dismiss()
        } label: {
            HStack(spacing: 14) {
                self.iconTile(symbol: "desktopcomputer", tint: .blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text(self.tr("ui.machine.local"))
                        .font(.app(size: 14, weight: .semibold))
                        .foregroundStyle(self.primaryTextColor)
                    Text(self.localControllerDisplay)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? Color.green : self.tertiaryTextColor)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(self.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(self.cardBackground(selected: isActive, hovered: hovered))
            .contentShape(RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isActive)
        .onHover { self.hoveringLocalCard = $0 }
    }

    private func remoteCard(_ machine: RemoteMachine) -> some View {
        let status = self.store.statusFor(machine.id)
        let isActive = self.store.activeTargetID == machine.id
        let hovered = self.hoveredMachineID == machine.id

        return HStack(spacing: 10) {
            Button {
                guard !isActive else { return }
                self.onSwitchTarget(.remote(machine))
                self.dismiss()
            } label: {
                HStack(spacing: 14) {
                    self.iconTile(symbol: "network", tint: self.statusTint(status, active: isActive))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(machine.name)
                            .font(.app(size: 14, weight: .semibold))
                            .foregroundStyle(self.primaryTextColor)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            self.statusDot(status)
                            Text(machine.displayAddress)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(self.secondaryTextColor)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isActive)

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(width: self.trailingActionAreaWidth, alignment: .trailing)
            } else {
                self.inlineActionGroup(
                    machineID: machine.id,
                    emphasized: hovered,
                    editAction: { self.editorMode = .edit(machine) },
                    deleteAction: { self.store.removeMachine(id: machine.id) })
                    .frame(width: self.trailingActionAreaWidth, alignment: .trailing)
            }
        }
        .padding(self.cardPadding)
        .background(self.cardBackground(selected: isActive, hovered: hovered))
        .onHover { isHovering in
            self.hoveredMachineID = isHovering ? machine.id : nil
            if !isHovering, self.hoveredRowAction?.machineID == machine.id {
                self.hoveredRowAction = nil
            }
        }
        .contextMenu {
            Button(self.tr("ui.machine.edit")) {
                self.editorMode = .edit(machine)
            }
            Divider()
            Button(self.tr("ui.action.delete"), role: .destructive) {
                self.store.removeMachine(id: machine.id)
            }
        }
    }

    private func editorContent(for mode: EditorMode) -> some View {
        RemoteMachineEditorCard(
            store: self.store,
            machine: mode.machine,
            surfaceFill: self.cardFill,
            borderColor: self.borderColor,
            separatorColor: self.separatorColor,
            secondaryTextColor: self.secondaryTextColor,
            tertiaryTextColor: self.tertiaryTextColor,
            onCancel: {
                self.editorMode = nil
            },
            onSave: {
                self.editorMode = nil
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func primaryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                .fill(self.accentTint))
        .overlay {
            RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                .stroke(self.accentTint.opacity(0.65), lineWidth: MenuBarLayoutTokens.stroke)
        }
        .shadow(color: Color.black.opacity(self.isDarkAppearance ? 0.20 : 0.10), radius: 10, x: 0, y: 4)
    }

    private func iconTile(symbol: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(tint.opacity(self.isDarkAppearance ? 0.16 : 0.10))
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(tint)
            }
    }

    private func inlineActionButton(
        machineID: UUID,
        rowAction: RowAction,
        emphasized: Bool,
        action: @escaping () -> Void) -> some View
    {
        let hoveredAction = HoveredRowAction(machineID: machineID, action: rowAction)
        let isHovered = self.hoveredRowAction == hoveredAction
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        let tint = self.actionButtonTint(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let fill = self.actionButtonFill(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let border = self.actionButtonBorder(for: rowAction, hovered: isHovered, emphasized: emphasized)
        let opacity = (emphasized || isHovered) ? 1.0 : 0.84

        return Button(action: action) {
            Image(systemName: rowAction.symbol)
                .font(.app(size: MenuBarLayoutTokens.FontSize.caption, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(shape.fill(fill))
                .overlay {
                    shape.stroke(border, lineWidth: MenuBarLayoutTokens.stroke)
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .accessibilityLabel(self.tr(rowAction.accessibilityKey))
        .onHover { isHovering in
            self
                .hoveredRowAction = isHovering ? hoveredAction :
                (self.hoveredRowAction == hoveredAction ? nil : self.hoveredRowAction)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: emphasized)
    }

    private func inlineActionGroup(
        machineID: UUID,
        emphasized: Bool,
        editAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void) -> some View
    {
        HStack(spacing: 6) {
            self.inlineActionButton(machineID: machineID, rowAction: .edit, emphasized: emphasized, action: editAction)
            self.inlineActionButton(
                machineID: machineID,
                rowAction: .delete,
                emphasized: emphasized,
                action: deleteAction)
        }
    }

    private func actionButtonTint(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if rowAction.isDestructive {
            return hovered ? .red : .red.opacity(emphasized ? 0.92 : 0.70)
        }

        return hovered ? self.accentTint : self.tertiaryTextColor.opacity(emphasized ? 1 : 0.88)
    }

    private func actionButtonFill(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if hovered {
            if rowAction.isDestructive {
                return Color.red.opacity(self.isDarkAppearance ? 0.18 : 0.10)
            }
            return self.accentTint.opacity(self.isDarkAppearance ? 0.18 : 0.09)
        }

        if emphasized {
            return Color.black.opacity(self.isDarkAppearance ? 0.18 : 0.06)
        }

        return Color.black.opacity(self.isDarkAppearance ? 0.12 : 0.035)
    }

    private func actionButtonBorder(for rowAction: RowAction, hovered: Bool, emphasized: Bool) -> Color {
        if hovered {
            return rowAction.isDestructive
                ? Color.red.opacity(self.isDarkAppearance ? 0.48 : 0.28)
                : self.accentTint.opacity(self.isDarkAppearance ? 0.48 : 0.28)
        }

        return self.borderColor.opacity(emphasized ? 1 : (self.isDarkAppearance ? 0.94 : 0.78))
    }

    private func cardBackground(selected: Bool, hovered: Bool) -> some View {
        RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
            .fill(selected ? self.cardSelectedFill : (hovered ? self.cardHoverFill : self.cardFill))
            .overlay {
                RoundedRectangle(cornerRadius: self.cardCornerRadius, style: .continuous)
                    .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
            }
            .shadow(color: Color.black.opacity(self.isDarkAppearance ? 0.12 : 0.06), radius: 14, x: 0, y: 3)
    }

    private func statusDot(_ status: MachineConnectionStatus) -> some View {
        Group {
            if case .checking = status {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(self.statusTint(status, active: false))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private func statusTint(_ status: MachineConnectionStatus, active: Bool) -> Color {
        switch status {
        case .unknown:
            self.tertiaryTextColor
        case .checking:
            .orange
        case .connected:
            active ? Color.green : Color(red: 0.10, green: 0.73, blue: 0.34)
        case .failed:
            .red
        }
    }
}

private struct RemoteMachineEditorCard: View {
    private enum Field {
        case name
        case host
        case port
        case secret
    }

    @ObservedObject var store: RemoteMachineStore
    let machine: RemoteMachine?
    let surfaceFill: Color
    let borderColor: Color
    let separatorColor: Color
    let secondaryTextColor: Color
    let tertiaryTextColor: Color
    let onCancel: () -> Void
    let onSave: () -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "9090"
    @State private var secret: String = ""
    @State private var useHTTPS = false
    @FocusState private var focusedField: Field?

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "clashbar.ui.language") ?? "") ?? .zhHans
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isValid: Bool {
        !self.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.host.trimmingCharacters(in: .whitespaces).isEmpty &&
            (Int(self.port) ?? 0) > 0 &&
            (Int(self.port) ?? 0) <= 65535
    }

    private var connectionPreview: String {
        let resolvedHost = self.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "controller.example.com"
            : self.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPort = self.port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "9090"
            : self.port.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = self.useHTTPS ? "https" : "http"
        return "\(scheme)://\(resolvedHost):\(resolvedPort)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(self.name.trimmingCharacters(in: .whitespaces).isEmpty ? self.tr("ui.machine.field.name") : self
                    .name)
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(self.connectionPreview)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.secondaryTextColor)
                    .lineLimit(1)
            }

            VStack(spacing: 0) {
                self.formTextRow(
                    title: self.tr("ui.machine.field.name"),
                    placeholder: self.tr("ui.machine.field.name"),
                    text: self.$name,
                    field: .name)
                self.separator
                self.formTextRow(
                    title: self.tr("ui.machine.field.host"),
                    placeholder: self.tr("ui.machine.field.host"),
                    text: self.$host,
                    field: .host)
                self.separator
                self.portProtocolRow
                self.separator
                self.secretRow
            }
            .background(self.formSurface)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                self.secondaryActionButton(title: self.tr("ui.action.cancel"), action: self.onCancel)
                self.primaryActionButton(title: self.tr("ui.machine.save"), action: self.save)
                    .disabled(!self.isValid)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let machine {
                self.name = machine.name
                self.host = machine.host
                self.port = "\(machine.port)"
                self.secret = machine.secret ?? ""
                self.useHTTPS = machine.useHTTPS
            } else {
                self.focusedField = .name
            }
        }
    }

    private func formTextRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field) -> some View
    {
        HStack(spacing: 10) {
            Text(title)
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: 13, weight: .regular))
                .focused(self.$focusedField, equals: field)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var portProtocolRow: some View {
        HStack(spacing: 10) {
            Text(self.tr("ui.machine.field.port"))
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            TextField(self.tr("ui.machine.field.port"), text: self.$port)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: 13, weight: .regular))
                .frame(width: 92)
                .focused(self.$focusedField, equals: .port)

            Spacer(minLength: 0)

            Toggle("HTTPS", isOn: self.$useHTTPS)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.app(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var secretRow: some View {
        HStack(spacing: 10) {
            Text(self.tr("ui.machine.field.secret"))
                .font(.app(size: 12, weight: .semibold))
                .foregroundStyle(self.secondaryTextColor)
                .frame(width: 56, alignment: .leading)

            SecureField(self.tr("ui.machine.field.secret"), text: self.$secret)
                .textFieldStyle(.roundedBorder)
                .font(.app(size: 13, weight: .regular))
                .focused(self.$focusedField, equals: .secret)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var separator: some View {
        Rectangle()
            .fill(self.separatorColor)
            .frame(height: MenuBarLayoutTokens.stroke)
    }

    private var formSurface: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(self.surfaceFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 3)
    }

    private func secondaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(self.surfaceFill))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(self.borderColor, lineWidth: MenuBarLayoutTokens.stroke)
        }
    }

    private func primaryActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlAccentColor)))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .controlAccentColor).opacity(0.65), lineWidth: MenuBarLayoutTokens.stroke)
        }
    }

    private func save() {
        let trimmedName = self.name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = self.host.trimmingCharacters(in: .whitespaces)
        let portValue = Int(self.port) ?? 9090
        let trimmedSecret = self.secret.trimmingCharacters(in: .whitespaces)

        if let existing = self.machine {
            var updated = existing
            updated.name = trimmedName
            updated.host = trimmedHost
            updated.port = portValue
            updated.secret = trimmedSecret.isEmpty ? nil : trimmedSecret
            updated.useHTTPS = self.useHTTPS
            self.store.updateMachine(updated)
        } else {
            self.store.addMachine(
                RemoteMachine(
                    name: trimmedName,
                    host: trimmedHost,
                    port: portValue,
                    secret: trimmedSecret.isEmpty ? nil : trimmedSecret,
                    useHTTPS: self.useHTTPS))
        }

        self.onSave()
    }
}
