import Foundation
import ProxyHelperShared
import ServiceManagement

enum ProxyHelperInstaller {
    static func installedHelperIsCurrent() -> Bool {
        let recorded = try? String(contentsOfFile: ProxyHelperConstants.installedVersionPath, encoding: .utf8)
        return FileManager.default.isExecutableFile(atPath: ProxyHelperConstants.installedHelperPath)
            && recorded?.trimmingCharacters(in: .whitespacesAndNewlines) == String(ProxyHelperConstants.helperVersion)
    }

    static func installBundledHelper() async throws {
        let bundleURL = Bundle.main.bundleURL
        let command = self.installShellCommand(
            sourceBinary: bundleURL.appendingPathComponent(ProxyHelperConstants.helperBundleProgram).path,
            sourcePlist: bundleURL.appendingPathComponent(ProxyHelperConstants.helperBundlePlist).path)

        try? await SMAppService.daemon(plistName: ProxyHelperConstants.daemonPlistName).unregister()
        try await Task.detached(priority: .userInitiated) {
            try AdministratorShell.run(
                command,
                cancelled: SystemProxyServiceError.helperAuthorizationCancelled,
                failed: SystemProxyServiceError.helperInstallFailed)
        }.value
    }

    private static func installShellCommand(sourceBinary: String, sourcePlist: String) -> String {
        let binary = AdministratorShell.shellQuoted(sourceBinary)
        let plist = AdministratorShell.shellQuoted(sourcePlist)
        let destBinary = AdministratorShell.shellQuoted(ProxyHelperConstants.installedHelperPath)
        let destPlist = AdministratorShell.shellQuoted(ProxyHelperConstants.installedPlistPath)
        let versionFile = AdministratorShell.shellQuoted(ProxyHelperConstants.installedVersionPath)
        let label = ProxyHelperConstants.machServiceName

        return """
        set -e
        /bin/mkdir -p /Library/PrivilegedHelperTools /Library/LaunchDaemons
        /bin/rm -f \(versionFile)
        /bin/launchctl bootout system/\(label) >/dev/null 2>&1 || true
        /bin/rm -f \(destBinary)
        /bin/cp -X \(binary) \(destBinary)
        /usr/sbin/chown root:wheel \(destBinary)
        /bin/chmod 755 \(destBinary)
        /bin/rm -f \(destPlist)
        /bin/cp -X \(plist) \(destPlist)
        /usr/sbin/chown root:wheel \(destPlist)
        /bin/chmod 644 \(destPlist)
        /bin/launchctl enable system/\(label) >/dev/null 2>&1 || true
        /bin/launchctl print system/\(label) >/dev/null 2>&1 || /bin/launchctl bootstrap system \(destPlist) || true
        /bin/launchctl kickstart -k system/\(label) >/dev/null 2>&1 || true
        echo \(ProxyHelperConstants.helperVersion) > \(versionFile)
        """
    }
}
