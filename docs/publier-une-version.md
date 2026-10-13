# Publier une version

Tout part de git : un tag `vX.Y.Z` suffit. Les utilisateurs reçoivent ensuite
la mise à jour depuis l'application.

## Étapes

1. Mettre à jour `VERSION` (`0.2.0`) **et** `PicoCore.version` dans
   `Packages/PicoCore/Sources/PicoCore/PicoCore.swift` (le script de DMG refuse
   de continuer si les deux diffèrent), ainsi que `MARKETING_VERSION` dans `project.yml`.
2. `make test` : tout doit passer.
3. Commit, puis :

       git tag v0.2.0
       git push && git push --tags

4. Le workflow `Release` (`.github/workflows/release.yml`) vérifie que le tag
   égale `VERSION`, lance les tests, construit `Pico-0.2.0.dmg` et son
   empreinte `Pico-0.2.0.dmg.sha256`, puis crée la Release GitHub avec les
   deux fichiers et des notes générées depuis les commits.

## Sans passer par GitHub Actions

    make release
    gh release create v0.2.0 build/Pico-0.2.0.dmg build/Pico-0.2.0.dmg.sha256 \
      --title "Pico 0.2.0" --generate-notes

## Ce que l'application vérifie avant d'installer

- La Release n'est ni un brouillon ni une pré-version, et son tag est une version.
- Elle contient `Pico-X.Y.Z.dmg` (même version que le tag) et `Pico-X.Y.Z.dmg.sha256`,
  hébergés sur github.com ou son CDN, en HTTPS.
- L'empreinte SHA-256 du DMG téléchargé est celle du fichier `.sha256`.
- L'app contenue dans le DMG porte l'identifiant `fr.vialet.pico`, la version annoncée,
  et une signature valide.

Si une étape échoue, l'application installée n'est pas touchée.

## Limite

Pico est signé ad hoc, sans certificat Apple Developer. L'empreinte publiée dans
la même Release protège d'un fichier corrompu, pas d'un compte GitHub compromis.
Signer et notariser avec un Developer ID supprimerait cette limite et l'avertissement
du premier lancement.
