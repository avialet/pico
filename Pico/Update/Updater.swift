import AppKit
import CryptoKit
import Observation
import PicoCore

enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(ReleaseInfo)
    case downloading(Double)
    case verifying
    case installing
    case failed(String)
}

struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Mises a jour a la volee : lit la derniere Release GitHub, telecharge le DMG,
/// verifie son empreinte SHA-256, controle l'app qu'il contient, puis la
/// remplace et relance Pico. Rien n'est modifie tant qu'une etape echoue.
@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    nonisolated static let repository = "avialet/pico"
    private nonisolated static let appIdentifier = "fr.vialet.pico"
    private static let autoKey = "PicoAutoUpdate"
    private static let lastCheckKey = "PicoLastUpdateCheck"

    private(set) var state: UpdateState = .idle
    private(set) var lastCheck: Date?
    var autoCheck: Bool {
        didSet { UserDefaults.standard.set(autoCheck, forKey: Self.autoKey) }
    }

    let currentVersion: SemanticVersion
    private var task: Task<Void, Never>?

    private init() {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        currentVersion = SemanticVersion(string: raw) ?? SemanticVersion(0)
        autoCheck = UserDefaults.standard.object(forKey: Self.autoKey) as? Bool ?? true
        lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    var available: ReleaseInfo? {
        if case .available(let r) = state { return r }
        return nil
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .verifying, .installing: true
        default: false
        }
    }

    // MARK: Verification de version

    /// Au lancement : au plus une verification par jour, si l'utilisateur l'accepte.
    func checkAutomatically() {
        guard autoCheck else { return }
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 24 * 3600 { return }
        check(userInitiated: false)
    }

    func check(userInitiated: Bool = true) {
        guard !isBusy else { return }
        state = .checking
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await Self.fetchLatest()
                lastCheck = Date()
                UserDefaults.standard.set(lastCheck, forKey: Self.lastCheckKey)
                state = release.map { $0.version > currentVersion ? .available($0) : .upToDate } ?? .upToDate
            } catch {
                state = userInitiated ? .failed(error.localizedDescription) : .idle
            }
        }
    }

    private nonisolated static func fetchLatest() async throws -> ReleaseInfo? {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Pico", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateError("Réponse invalide du serveur.") }
        switch http.statusCode {
        case 200: break
        case 404: return nil // aucune release publiee
        case 403, 429: throw UpdateError("GitHub limite les requêtes pour le moment. Réessayez dans quelques minutes.")
        default: throw UpdateError("GitHub a répondu \(http.statusCode).")
        }
        guard let release = ReleaseInfo.parse(json: data) else {
            throw UpdateError("La dernière version publiée est incomplète (DMG ou empreinte manquants).")
        }
        return release
    }

    // MARK: Installation

    func install() {
        guard let release = available, !isBusy else { return }
        let bundle = Bundle.main.bundleURL
        let parent = bundle.deletingLastPathComponent()
        guard bundle.pathExtension == "app", FileManager.default.isWritableFile(atPath: parent.path),
              FileManager.default.isWritableFile(atPath: bundle.path) else {
            NSWorkspace.shared.open(release.pageURL)
            state = .failed("Pico est installé dans un dossier protégé : la page de la version s'ouvre pour un téléchargement manuel.")
            return
        }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let staged = try await Self.prepare(release) { [weak self] progress in
                    Task { @MainActor in self?.state = .downloading(progress) }
                } onPhase: { [weak self] phase in
                    Task { @MainActor in self?.state = phase }
                }
                state = .installing
                try Self.launchReplacement(newApp: staged, destination: bundle)
                try? await Task.sleep(for: .milliseconds(400))
                NSApp.terminate(nil)
            } catch is CancellationError {
                state = .available(release)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func dismissError() {
        if case .failed = state { state = .idle }
    }

    /// Telecharge, verifie et extrait la nouvelle app dans un dossier temporaire.
    private nonisolated static func prepare(_ release: ReleaseInfo,
                                            onProgress: @escaping @Sendable (Double) -> Void,
                                            onPhase: @escaping @Sendable (UpdateState) -> Void) async throws -> URL {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("pico-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        var succeeded = false
        defer { if !succeeded { try? fm.removeItem(at: work) } }

        // 1. Empreinte attendue.
        var req = URLRequest(url: release.checksumURL)
        req.timeoutInterval = 20
        req.setValue("Pico", forHTTPHeaderField: "User-Agent")
        let (sumData, sumResponse) = try await URLSession.shared.data(for: req)
        guard (sumResponse as? HTTPURLResponse)?.statusCode == 200,
              let expected = ReleaseInfo.parseChecksum(String(decoding: sumData, as: UTF8.self), fileName: release.dmgName) else {
            throw UpdateError("L'empreinte de vérification de cette version est introuvable ou illisible.")
        }

        // 2. Telechargement.
        let dmg = work.appendingPathComponent(release.dmgName)
        try await download(release.dmgURL, to: dmg, onProgress: onProgress)
        try Task.checkCancellation()

        // 3. Verification SHA-256.
        onPhase(.verifying)
        let actual = try sha256(of: dmg)
        guard actual == expected else {
            throw UpdateError("Le fichier téléchargé est corrompu (empreinte différente). Rien n'a été installé.")
        }

        // 4. Extraction de l'app, puis controles.
        let mount = work.appendingPathComponent("mnt")
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        _ = try await run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noverify", "-mountpoint", mount.path, dmg.path])
        let stage = work.appendingPathComponent("stage")
        let staged = stage.appendingPathComponent("Pico.app")
        do {
            try fm.createDirectory(at: stage, withIntermediateDirectories: true)
            _ = try await run("/usr/bin/ditto", [mount.appendingPathComponent("Pico.app").path, staged.path])
        } catch {
            _ = try? await run("/usr/bin/hdiutil", ["detach", mount.path, "-force"])
            throw UpdateError("Le DMG ne contient pas Pico.app.")
        }
        _ = try? await run("/usr/bin/hdiutil", ["detach", mount.path, "-force"])

        guard let info = NSDictionary(contentsOf: staged.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == appIdentifier,
              info["CFBundleShortVersionString"] as? String == release.version.description else {
            throw UpdateError("L'application téléchargée ne correspond pas à la version annoncée.")
        }
        do {
            _ = try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", staged.path])
        } catch {
            throw UpdateError("La signature de l'application téléchargée est invalide.")
        }
        succeeded = true
        return staged
    }

    private nonisolated static func download(_ url: URL, to file: URL,
                                             onProgress: @Sendable (Double) -> Void) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Pico", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError("Téléchargement impossible.") }
        let total = response.expectedContentLength
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        var buffer = Data(); buffer.reserveCapacity(1 << 18)
        var received: Int64 = 0
        var lastReport = Date.distantPast
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 1 << 18 {
                try handle.write(contentsOf: buffer); received += Int64(buffer.count); buffer.removeAll(keepingCapacity: true)
                try Task.checkCancellation()
                if total > 0, Date().timeIntervalSince(lastReport) > 0.05 {
                    onProgress(min(1, Double(received) / Double(total))); lastReport = Date()
                }
            }
        }
        if !buffer.isEmpty { try handle.write(contentsOf: buffer); received += Int64(buffer.count) }
        if total > 0, received != total { throw UpdateError("Téléchargement incomplet.") }
        onProgress(1)
    }

    private nonisolated static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Lance un script detache : il attend la fermeture de Pico, remplace le
    /// bundle (en gardant l'ancien tant que la copie n'a pas reussi), puis rouvre l'app.
    private nonisolated static func launchReplacement(newApp: URL, destination: URL) throws {
        let script = """
        #!/bin/sh
        PID="$1"; NEW="$2"; DEST="$3"
        i=0
        while kill -0 "$PID" 2>/dev/null; do
          i=$((i+1)); [ "$i" -gt 150 ] && exit 1
          sleep 0.1
        done
        OLD="$DEST.old-update"
        rm -rf "$OLD"
        if mv "$DEST" "$OLD"; then
          if /usr/bin/ditto "$NEW" "$DEST"; then
            rm -rf "$OLD"
          else
            rm -rf "$DEST"; mv "$OLD" "$DEST"
          fi
        fi
        rm -rf "$(dirname "$(dirname "$NEW")")"
        /usr/bin/open "$DEST"
        """
        let file = newApp.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("replace.sh")
        try script.write(to: file, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [file.path, String(ProcessInfo.processInfo.processIdentifier), newApp.path, destination.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        try process.run()
    }

    @discardableResult
    private nonisolated static func run(_ tool: String, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: tool)
                process.arguments = arguments
                let out = Pipe(), err = Pipe()
                process.standardOutput = out
                process.standardError = err
                do { try process.run() } catch { continuation.resume(throwing: error); return }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                _ = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: String(decoding: data, as: UTF8.self))
                } else {
                    continuation.resume(throwing: UpdateError("\((tool as NSString).lastPathComponent) a échoué (\(process.terminationStatus))."))
                }
            }
        }
    }
}
