import SwiftUI
import PicoCore

/// Bandeau discret en bas de la barre laterale.
struct UpdateBanner: View {
    @State private var updater = Updater.shared

    var body: some View {
        if let release = updater.available {
            card(release)
        } else if updater.isBusy, updater.state != .checking {
            progress
        }
    }

    private func card(_ release: ReleaseInfo) -> some View {
        Button { updater.install() } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.sea.gradient)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pico \(release.version) est disponible")
                        .font(Theme.ui(12.5, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("Installer et relancer").font(Theme.ui(11.5)).foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.sea.opacity(0.13)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var progress: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(UpdateText.status(updater.state)).font(Theme.ui(12, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(10)
        .padding(.horizontal, 12)
    }
}

enum UpdateText {
    static func status(_ state: UpdateState) -> String {
        switch state {
        case .idle: ""
        case .checking: "Recherche en cours…"
        case .upToDate: "Pico est à jour."
        case .available(let r): "La version \(r.version) est disponible."
        case .downloading(let p): "Téléchargement… \(Int(p * 100)) %"
        case .verifying: "Vérification du fichier…"
        case .installing: "Installation, Pico va se relancer…"
        case .failed(let message): message
        }
    }
}

/// Carte "Mises a jour" des reglages.
struct UpdateCard: View {
    @State private var updater = Updater.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Version \(updater.currentVersion)")
                    .font(Theme.ui(13.5, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                action
            }
            if case .downloading(let p) = updater.state {
                ProgressView(value: p).tint(Theme.sea)
            }
            let text = UpdateText.status(updater.state)
            if !text.isEmpty {
                Text(text)
                    .font(Theme.ui(12))
                    .foregroundStyle(isFailure ? Theme.danger : Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let release = updater.available, !release.notes.isEmpty {
                ScrollView {
                    Text(release.notes).font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 110)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink.opacity(0.05)))
            }
            Toggle("Rechercher automatiquement (une fois par jour)", isOn: $updater.autoCheck)
            if let last = updater.lastCheck {
                Text("Dernière recherche : \(last.formatted(.relative(presentation: .named)))")
                    .font(Theme.ui(11.5)).foregroundStyle(Theme.inkFaint)
            }
            Text("Le seul échange réseau de Pico : la lecture de la dernière version publiée sur GitHub. Aucune donnée n'est envoyée.")
                .font(Theme.ui(11.5)).foregroundStyle(Theme.inkFaint).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isFailure: Bool {
        if case .failed = updater.state { return true }
        return false
    }

    @ViewBuilder
    private var action: some View {
        if updater.available != nil {
            Button("Installer et relancer") { updater.install() }
                .buttonStyle(.borderedProminent).tint(Theme.sea).controlSize(.small)
                .disabled(updater.isBusy)
        } else {
            Button("Rechercher") { updater.check() }
                .controlSize(.small)
                .disabled(updater.isBusy)
        }
    }
}
