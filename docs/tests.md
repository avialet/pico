# Tests

Les Command Line Tools n'embarquent ni XCTest ni Swift Testing. En attendant
Xcode, les tests du noyau vivent dans
`Packages/PicoCore/Sources/picocore-check/` et tournent avec :

    make test        # = swift run picocore-check [filtre]

API du harnais (`Check.swift`) : `Test("nom") { ... }`, `expect(cond)`,
`expectEqual(a, b)`, `expectThrows { ... }`.

## Migration vers Swift Testing (des que Xcode est installe)

1. Deplacer les fichiers de tests vers `Packages/PicoCore/Tests/PicoCoreTests/`.
2. Remplacer `Test("x") {` par `@Test func x() throws {`, `expect(` par
   `#expect(`, `expectEqual(a, b)` par `#expect(a == b)`.
3. Supprimer `Check.swift`, `main.swift` et la cible `picocore-check`,
   ajouter un `testTarget` dans `Package.swift`.
