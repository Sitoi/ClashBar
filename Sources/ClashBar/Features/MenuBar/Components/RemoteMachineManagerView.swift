import SwiftUI

struct RemoteMachineManagerView: View {
    @ObservedObject var store: RemoteMachineStore
    let onSwitchTarget: (MachineTarget) -> Void
    @State private var editingMachine: RemoteMachine?
    @State private var isAddingNew = false
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "clashbar.ui.language") ?? "") ?? .zhHans
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    var body: some View {
        VStack(spacing: 0) {
            self.headerBar
            Divider()
            self.machineList
            Divider()
            self.bottomBar
        }
        .onAppear {
            self.store.startPeriodicConnectivityChecks()
        }
        .onDisappear {
            self.store.stopPeriodicConnectivityChecks()
        }
    }

    private var headerBar: some View {
        HStack {
            Text(self.tr("ui.machine.manage"))
                .font(.headline)
            Spacer()
            Button {
                self.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var machineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                self.localRow
                Divider().padding(.horizontal, 16)

                if self.store.machines.isEmpty {
                    Text(self.tr("ui.machine.empty"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(self.store.machines) { machine in
                        self.machineRow(machine)
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var localRow: some View {
        let isActive = self.store.activeTarget.isLocal
        return HStack(spacing: 10) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 14))
                .foregroundStyle(isActive ? .blue : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(self.tr("ui.machine.return_local"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? .primary : .secondary)
            }
            Spacer()
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            self.onSwitchTarget(.local)
            self.dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func machineRow(_ machine: RemoteMachine) -> some View {
        let isActive = self.store.activeTargetID == machine.id
        let status = self.store.statusFor(machine.id)

        return HStack(spacing: 10) {
            self.statusDot(status)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(machine.name)
                        .font(.system(size: 13, weight: .medium))
                    if isActive {
                        Text("(\(self.tr("ui.machine.active")))")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }
                HStack(spacing: 4) {
                    Text(machine.displayAddress)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("· \(status.shortLabel)")
                        .font(.system(size: 10))
                        .foregroundStyle(self.statusTextColor(status))
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            }

            Button {
                self.editingMachine = machine
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            Button {
                self.store.removeMachine(id: machine.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isActive else { return }
            self.onSwitchTarget(.remote(machine))
            self.dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func statusDot(_ status: MachineConnectionStatus) -> some View {
        switch status {
        case .unknown:
            Circle().fill(.gray).frame(width: 8, height: 8)
        case .checking:
            ProgressView().controlSize(.mini)
        case .connected:
            Circle().fill(.green).frame(width: 8, height: 8)
        case .failed:
            Circle().fill(.red).frame(width: 8, height: 8)
        }
    }

    private func statusTextColor(_ status: MachineConnectionStatus) -> Color {
        switch status {
        case .unknown: .gray
        case .checking: .secondary
        case .connected: .green
        case .failed: .red
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                self.isAddingNew = true
            } label: {
                Label(self.tr("ui.machine.add"), systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .sheet(isPresented: self.$isAddingNew) {
            RemoteMachineEditView(store: self.store, machine: nil) {
                self.isAddingNew = false
            }
        }
        .sheet(item: self.$editingMachine) { machine in
            RemoteMachineEditView(store: self.store, machine: machine) {
                self.editingMachine = nil
            }
        }
    }
}

struct RemoteMachineEditView: View {
    @ObservedObject var store: RemoteMachineStore
    let machine: RemoteMachine?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "9090"
    @State private var secret: String = ""
    @State private var useHTTPS: Bool = false

    private var language: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "clashbar.ui.language") ?? "") ?? .zhHans
    }

    private func tr(_ key: String) -> String {
        L10n.t(key, language: self.language)
    }

    private var isValid: Bool {
        !self.name.trimmingCharacters(in: .whitespaces).isEmpty &&
            !self.host.trimmingCharacters(in: .whitespaces).isEmpty &&
            (Int(self.port) ?? 0) > 0 && (Int(self.port) ?? 0) <= 65535
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(self.machine == nil ? self.tr("ui.machine.add") : self.tr("ui.machine.edit"))
                .font(.headline)

            Form {
                TextField(self.tr("ui.machine.field.name"), text: self.$name)
                TextField(self.tr("ui.machine.field.host"), text: self.$host)
                TextField(self.tr("ui.machine.field.port"), text: self.$port)
                SecureField(self.tr("ui.machine.field.secret"), text: self.$secret)
                Toggle("HTTPS", isOn: self.$useHTTPS)
            }

            HStack {
                Button(self.tr("ui.action.cancel")) {
                    self.onDismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(self.tr("ui.machine.save")) {
                    let trimmedName = self.name.trimmingCharacters(in: .whitespaces)
                    let trimmedHost = self.host.trimmingCharacters(in: .whitespaces)
                    let portValue = Int(port) ?? 9090
                    let trimmedSecret = self.secret.trimmingCharacters(in: .whitespaces)

                    if let existing = machine {
                        var updated = existing
                        updated.name = trimmedName
                        updated.host = trimmedHost
                        updated.port = portValue
                        updated.secret = trimmedSecret.isEmpty ? nil : trimmedSecret
                        updated.useHTTPS = self.useHTTPS
                        self.store.updateMachine(updated)
                    } else {
                        let newMachine = RemoteMachine(
                            name: trimmedName,
                            host: trimmedHost,
                            port: portValue,
                            secret: trimmedSecret.isEmpty ? nil : trimmedSecret,
                            useHTTPS: self.useHTTPS)
                        self.store.addMachine(newMachine)
                    }
                    self.onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!self.isValid)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            if let machine {
                self.name = machine.name
                self.host = machine.host
                self.port = "\(machine.port)"
                self.secret = machine.secret ?? ""
                self.useHTTPS = machine.useHTTPS
            }
        }
    }
}
