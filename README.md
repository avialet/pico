# Pico

Gestionnaire de taches natif macOS 26 (SwiftUI + GRDB). Capture ultra-rapide,
Aujourd'hui / A venir, zones et projets, portes d'entree CLI / URL scheme /
App Intents pour y pousser les tickets du bureau.

## Prerequis

- Xcode 26 (`sudo xcode-select -s /Applications/Xcode.app`)
- `brew install xcodegen`

## Commandes

    make gen     # genere Pico.xcodeproj depuis project.yml
    make test    # tests PicoCore (Swift Testing)
    make build   # construit build/Pico.app
    make run     # construit puis lance l'app
    make cli     # construit le binaire `pico` dans build/

Le package `Packages/PicoCore` se construit et se teste sans Xcode
(`swift test` avec les Command Line Tools).
