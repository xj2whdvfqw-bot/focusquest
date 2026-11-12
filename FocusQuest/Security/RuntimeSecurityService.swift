import Darwin
import Foundation
import MachO

protocol RuntimeSecurityServiceProtocol: Sendable {
    func integrityReport() -> RuntimeIntegrityReport
}

struct RuntimeIntegrityReport: Sendable {
    let isCompromised: Bool
    let findings: [String]
}

struct RuntimeSecurityService: RuntimeSecurityServiceProtocol {
    func integrityReport() -> RuntimeIntegrityReport {
        #if targetEnvironment(simulator)
        return RuntimeIntegrityReport(isCompromised: false, findings: [])
        #else
        var findings: [String] = []
        let suspiciousPaths = ["/Applications/Cydia.app", "/Applications/Sileo.app", "/bin/bash", "/usr/sbin/sshd", "/etc/apt", "/private/var/lib/apt/", "/var/jb"]
        findings += suspiciousPaths.filter { FileManager.default.fileExists(atPath: $0) }

        let probe = "/private/focusquest-integrity-probe"
        if (try? Data([0]).write(to: URL(fileURLWithPath: probe), options: .atomic)) != nil {
            try? FileManager.default.removeItem(atPath: probe)
            findings.append("sandbox-write")
        }

        let suspiciousImages = ["MobileSubstrate", "SubstrateLoader", "FridaGadget", "cycript", "SSLKillSwitch"]
        for index in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(index) else { continue }
            let image = String(cString: name)
            if suspiciousImages.contains(where: image.localizedCaseInsensitiveContains) { findings.append(image) }
        }
        #if !DEBUG
        if debuggerAttached() { findings.append("debugger-attached") }
        #endif
        return RuntimeIntegrityReport(isCompromised: !findings.isEmpty, findings: findings)
        #endif
    }

    #if !DEBUG && !targetEnvironment(simulator)
    private func debuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        return result == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
    }
    #endif
}