import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

private enum EditorMode: Hashable {
    case add
    case edit(RemoteMachine)

    var machine: RemoteMachine? {
        if case let .edit(machine) = self {
            return machine
        }
        return nil
    }
}

private enum RemoteMachineManagerTokens {
    static let panelHeight: CGFloat = 500
    static let contentPadding: CGFloat = T.space8 * 2
    static let headerBottomPadding: CGFloat = T.space6 * 2
    static let rowSpacing: CGFloat = T.space8
    static let rowContentSpacing: CGFloat = 12
    static let rowPadding: CGFloat = 10
    static let rowCornerRadius: CGFloat = T.panelCornerRadius
    static let rowIconSize: CGFloat = T.rowHeight
    static let rowActionSize: CGFloat = 26
    static let editorSpacing: CGFloat = 20
    static let formSpacing: CGFloat = T.space8 * 2
    static let fieldSpacing: CGFloat = T.space6
    static let portFieldWidth: CGFloat = 100
    static let switchAnimationDuration: CGFloat = 0.15
    static let editorAnimationResponse: CGFloat = 0.35
    static let selectionFillOpacity: CGFloat = 0.10
}

private struct RemoteMachineManagerPalette {
    let colorScheme: ColorScheme

    private var isDarkAppearance: Bool {
        self.colorScheme == .dark
    }

    var panelBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    var primaryLabel: Color {
        Color(nsColor: .labelColor)
    }

    var secondaryLabel: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.labelSecondary : T.Theme.Light.labelSecondary)
    }

    var tertiaryLabel: Color {
        Color(nsColor: .labelColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.labelTertiary : T.Theme.Light.labelTertiary)
    }

    var accent: Color {
        Color(nsColor: .controlAccentColor).opacity(T.Opacity.solid)
    }

    var positive: Color {
        Color(nsColor: .systemGreen).opacity(T.Opacity.solid)
    }

    var warning: Color {
        Color(nsColor: .systemOrange).opacity(T.Opacity.solid)
    }

    var critical: Color {
        Color(nsColor: .systemRed).opacity(T.Opacity.solid)
    }

    var controlFill: Color {
        Color(nsColor: self.isDarkAppearance ? .controlBackgroundColor : .windowBackgroundColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.controlFill : T.Theme.Light.controlFill)
    }

    var hoverFill: Color {
        Color(nsColor: .selectedContentBackgroundColor)
            .opacity(self.isDarkAppearance ? T.Theme.Dark.hoverFill : T.Theme.Light.hoverFill)
    }

    func rowFill(active: Bool, hovered: Bool) -> Color {
        if active {
            return Color(nsColor: .controlAccentColor).opacity(RemoteMachineManagerTokens.selectionFillOpacity)
        }
        if hovered {
            return self.hoverFill
        }
        return self.controlFill
    }

    func actionBackground(hovered: Bool, destructive: Bool = false) -> Color {
        guard hovered else { return .clear }
        return destructive ? self.critical.opacity(T.Opacity.tint) : self.hoverFill
    }

    func actionForeground(hovered: Bool, destructive: Bool = false) -> Color {
        if destructive {
            return hovered ? self.critical : self.secondaryLabel
        }
        return hovered ? self.primaryLabel : self.secondaryLabel
    }
}

struct RemoteMachineManagerView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var store: RemoteMachineStore
    let localControllerDisplay: String
    let onSwitchTarget: (MachineTarget) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var editorMode: EditorMode?
    @State private var isHoveringLocalRow = false

    private var palette: RemoteMachineManagerPalette {
        .init(colorScheme: self.colorScheme)
    }

    private var headerTitle: String {
        if let editorMode {
            return editorMode.machine == nil ? self.tr("ui.machine.add") : self.tr("ui.machine.edit")
        }
        return self.tr("ui.machine.manage")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: T.space6) {
                Label(self.headerTitle, systemImage: "network")
                    .font(.app(size: T.FontSize.title3, weight: .semibold))
                    .foregroundStyle(self.palette.primaryLabel)

                Spacer()

                Button {
                    if self.editorMode != nil {
                        self.editorMode = nil
                    } else {
                        self.dismiss()
                    }
                } label: {
                    Image(systemName: self.editorMode != nil ? "chevron.left.circle.fill" : "xmark.circle.fill")
                        .font(.app(size: T.FontSize.title3, weight: .semibold))
                        .foregroundStyle(self.palette.tertiaryLabel)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(self.editorMode != nil ? self.tr("ui.action.cancel") : self.tr("ui.action.close"))
            }
            .padding([.horizontal, .top], RemoteMachineManagerTokens.contentPadding)
            .padding(.bottom, RemoteMachineManagerTokens.headerBottomPadding)

            ZStack(alignment: .topLeading) {
                if let mode = self.editorMode {
                    RemoteMachineEditorView(store: self.store, mode: mode) {
                        self.editorMode = nil
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)))
                } else {
                    self.machineList
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(self.palette.panelBackground)
        .frame(width: T.panelWidth, height: RemoteMachineManagerTokens.panelHeight)
        .animation(
            .spring(response: RemoteMachineManagerTokens.editorAnimationResponse, dampingFraction: 1),
            value: self.editorMode)
        .onAppear { self.store.startPeriodicConnectivityChecks() }
        .onDisappear { self.store.stopPeriodicConnectivityChecks() }
    }

    private var machineList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RemoteMachineManagerTokens.rowSpacing) {
                    self.localMachineRow

                    ForEach(self.store.machines) { machine in
                        RemoteMachineRowView(
                            machine: machine,
                            store: self.store,
                            onEdit: { self.editorMode = .edit(machine) },
                            editAccessibilityLabel: self.tr("ui.machine.edit"),
                            deleteAccessibilityLabel: self.tr("ui.action.delete"),
                            onSwitchTarget: self.onSwitchTarget,
                            dismiss: self.dismiss)
                    }
                }
                .padding(.horizontal, RemoteMachineManagerTokens.contentPadding)
                .padding(.bottom, RemoteMachineManagerTokens.contentPadding)
            }
            .scrollIndicators(.hidden)

            Button {
                self.editorMode = .add
            } label: {
                Label(self.tr("ui.machine.add"), systemImage: "plus")
                    .font(.app(size: T.FontSize.body, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, T.space8)
            }
            .appBorderedButtonStyle(prominent: true)
            .controlSize(.large)
            .padding(.horizontal, RemoteMachineManagerTokens.contentPadding)
            .padding(.bottom, RemoteMachineManagerTokens.contentPadding)
        }
    }

    private var localMachineRow: some View {
        let isActive = self.store.activeTarget.isLocal

        return Button {
            guard !isActive else { return }
            self.onSwitchTarget(.local)
            self.dismiss()
        } label: {
            HStack(spacing: RemoteMachineManagerTokens.rowContentSpacing) {
                Image(systemName: "desktopcomputer")
                    .font(.app(size: T.FontSize.body, weight: .semibold))
                    .foregroundStyle(self.palette.accent)
                    .frame(width: RemoteMachineManagerTokens.rowIconSize)

                VStack(alignment: .leading, spacing: T.space4) {
                    Text(self.tr("ui.machine.local"))
                        .font(.app(size: T.FontSize.body, weight: .semibold))
                        .foregroundStyle(self.palette.primaryLabel)

                    Text(self.localControllerDisplay)
                        .font(.app(size: T.FontSize.caption, weight: .regular))
                        .foregroundStyle(self.palette.secondaryLabel)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(self.palette.positive)
                }
            }
            .padding(RemoteMachineManagerTokens.rowPadding)
            .background(
                self.palette.rowFill(active: isActive, hovered: self.isHoveringLocalRow && !isActive),
                in: .rect(cornerRadius: RemoteMachineManagerTokens.rowCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: RemoteMachineManagerTokens.switchAnimationDuration)) {
                self.isHoveringLocalRow = hovering
            }
        }
    }
}

private struct RemoteMachineRowView: View {
    let machine: RemoteMachine
    @ObservedObject var store: RemoteMachineStore
    let onEdit: () -> Void
    let editAccessibilityLabel: String
    let deleteAccessibilityLabel: String
    let onSwitchTarget: (MachineTarget) -> Void
    let dismiss: DismissAction

    @Environment(\.colorScheme) private var colorScheme

    @State private var isHoveringRow = false
    @State private var isHoveringEdit = false
    @State private var isHoveringDelete = false

    private var palette: RemoteMachineManagerPalette {
        .init(colorScheme: self.colorScheme)
    }

    var body: some View {
        let status = self.store.statusFor(self.machine.id)
        let isActive = self.store.activeTargetID == self.machine.id
        let isSwitchEnabled = status.isConnected && !isActive

        return HStack(spacing: T.space6) {
            Button {
                guard isSwitchEnabled else { return }
                self.onSwitchTarget(.remote(self.machine))
                self.dismiss()
            } label: {
                HStack(spacing: RemoteMachineManagerTokens.rowContentSpacing) {
                    Image(systemName: "network")
                        .font(.app(size: T.FontSize.body, weight: .semibold))
                        .foregroundStyle(self.statusTint(status))
                        .frame(width: RemoteMachineManagerTokens.rowIconSize)

                    VStack(alignment: .leading, spacing: T.space4) {
                        Text(self.machine.name)
                            .font(.app(size: T.FontSize.body, weight: .semibold))
                            .foregroundStyle(self.palette.primaryLabel)

                        HStack(spacing: T.space4) {
                            self.statusDot(status)

                            Text(self.machine.displayAddress)
                                .font(.app(size: T.FontSize.caption, weight: .regular))
                                .foregroundStyle(self.palette.secondaryLabel)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isSwitchEnabled)

            HStack(spacing: T.space6) {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(self.palette.positive)
                }

                self.rowActionButton(
                    symbol: "pencil",
                    accessibilityLabel: self.editAccessibilityLabel,
                    hovered: self.isHoveringEdit,
                    destructive: false)
                {
                    self.onEdit()
                }
                .onHover { self.isHoveringEdit = $0 }

                self.rowActionButton(
                    symbol: "trash",
                    accessibilityLabel: self.deleteAccessibilityLabel,
                    hovered: self.isHoveringDelete,
                    destructive: true)
                {
                    self.store.removeMachine(id: self.machine.id)
                }
                .onHover { self.isHoveringDelete = $0 }
            }
        }
        .padding(RemoteMachineManagerTokens.rowPadding)
        .background(
            self.palette.rowFill(active: isActive, hovered: self.isHoveringRow && !isActive),
            in: .rect(cornerRadius: RemoteMachineManagerTokens.rowCornerRadius))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: RemoteMachineManagerTokens.switchAnimationDuration)) {
                self.isHoveringRow = hovering
            }
        }
    }

    private func rowActionButton(
        symbol: String,
        accessibilityLabel: String,
        hovered: Bool,
        destructive: Bool,
        action: @escaping () -> Void) -> some View
    {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(
                    width: RemoteMachineManagerTokens.rowActionSize,
                    height: RemoteMachineManagerTokens.rowActionSize)
                .background(
                    self.palette.actionBackground(hovered: hovered, destructive: destructive),
                    in: .rect(cornerRadius: T.cornerRadius))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(self.palette.actionForeground(hovered: hovered, destructive: destructive))
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func statusDot(_ status: MachineConnectionStatus) -> some View {
        if case .checking = status {
            ProgressView()
                .controlSize(.mini)
        } else {
            Circle()
                .fill(self.statusTint(status))
                .frame(width: T.space6, height: T.space6)
        }
    }

    private func statusTint(_ status: MachineConnectionStatus) -> Color {
        switch status {
        case .unknown:
            self.palette.secondaryLabel
        case .checking:
            self.palette.warning
        case .connected:
            self.palette.positive
        case .failed:
            self.palette.critical
        }
    }
}

private struct RemoteMachineEditorView: TranslatingView {
    @EnvironmentObject var appViewModel: AppViewModel
    @ObservedObject var store: RemoteMachineStore
    let mode: EditorMode
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "9090"
    @State private var secret: String = ""
    @State private var useHTTPS = false

    @FocusState private var isNameFocused: Bool

    private var palette: RemoteMachineManagerPalette {
        .init(colorScheme: self.colorScheme)
    }

    private var isFormValid: Bool {
        !self.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.host.trimmingCharacters(in: .whitespaces).isEmpty &&
            (Int(self.port) ?? 0) > 0 && (Int(self.port) ?? 0) <= 65535
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RemoteMachineManagerTokens.editorSpacing) {
            VStack(alignment: .leading, spacing: T.space4) {
                Text(self.name.trimmingCharacters(in: .whitespaces).isEmpty ? self.tr("ui.machine.field.name") : self
                    .name)
                    .font(.app(size: T.FontSize.body, weight: .semibold))
                    .foregroundStyle(self.palette.primaryLabel)

                Text(self.connectionPreview)
                    .font(.app(size: T.FontSize.caption, weight: .regular))
                    .foregroundStyle(self.palette.secondaryLabel)
            }
            .padding(.bottom, T.space8)

            VStack(alignment: .leading, spacing: RemoteMachineManagerTokens.formSpacing) {
                self.nameField

                HStack(spacing: RemoteMachineManagerTokens.formSpacing) {
                    self.inputField(title: self.tr("ui.machine.field.host"), text: self.$host, isSecure: false)

                    self.inputField(title: self.tr("ui.machine.field.port"), text: self.$port, isSecure: false)
                        .frame(maxWidth: RemoteMachineManagerTokens.portFieldWidth)
                }

                self.inputField(title: self.tr("ui.machine.field.secret"), text: self.$secret, isSecure: true)

                HStack {
                    Text("HTTPS")
                        .font(.app(size: T.FontSize.body, weight: .medium))
                        .foregroundStyle(self.palette.secondaryLabel)

                    Spacer()

                    Toggle("", isOn: self.$useHTTPS)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.regular)
                }
            }

            Spacer()

            Button(action: self.save) {
                Text(self.tr("ui.machine.save"))
                    .font(.app(size: T.FontSize.body, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, T.space8)
            }
            .appBorderedButtonStyle(prominent: true)
            .controlSize(.large)
            .disabled(!self.isFormValid)
        }
        .padding(.horizontal, RemoteMachineManagerTokens.contentPadding)
        .padding(.bottom, RemoteMachineManagerTokens.contentPadding)
        .onAppear {
            if let machine = self.mode.machine {
                self.name = machine.name
                self.host = machine.host
                self.port = "\(machine.port)"
                self.secret = machine.secret ?? ""
                self.useHTTPS = machine.useHTTPS
            } else {
                self.isNameFocused = true
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: RemoteMachineManagerTokens.fieldSpacing) {
            Text(self.tr("ui.machine.field.name"))
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(self.palette.secondaryLabel)

            TextField("", text: self.$name)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .font(.app(size: T.FontSize.body, weight: .regular))
                .focused(self.$isNameFocused)
        }
    }

    private func inputField(title: String, text: Binding<String>, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: RemoteMachineManagerTokens.fieldSpacing) {
            Text(title)
                .font(.app(size: T.FontSize.body, weight: .medium))
                .foregroundStyle(self.palette.secondaryLabel)

            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .font(.app(size: T.FontSize.body, weight: .regular))
        }
    }

    private var connectionPreview: String {
        let resolvedHost = self.host.trimmingCharacters(in: .whitespaces).isEmpty ? "controller.example.com" : self.host
        let resolvedPort = self.port.trimmingCharacters(in: .whitespaces).isEmpty ? "9090" : self.port
        let scheme = self.useHTTPS ? "https" : "http"
        return self.tr("ui.machine.preview", scheme, resolvedHost, resolvedPort)
    }

    private func save() {
        let trimmedName = self.name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = self.host.trimmingCharacters(in: .whitespaces)
        let portValue = Int(self.port) ?? 9090
        let trimmedSecret = self.secret.trimmingCharacters(in: .whitespaces)

        let machine = RemoteMachine(
            id: self.mode.machine?.id ?? UUID(),
            name: trimmedName,
            host: trimmedHost,
            port: portValue,
            secret: trimmedSecret.isEmpty ? nil : trimmedSecret,
            useHTTPS: self.useHTTPS)

        if self.mode.machine != nil {
            self.store.updateMachine(machine)
        } else {
            self.store.addMachine(machine)
        }

        self.onComplete()
    }
}
