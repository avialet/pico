import PicoCore

run([
    ("Smoke", [
        Test("versionIsSet") {
            expectEqual(PicoCore.version, "0.1.0")
        },
    ]),
    dayDateTests,
    recurrenceTests,
    todoServiceTests,
    projectServiceTests,
    changeLogTests,
    parserTests,
])
