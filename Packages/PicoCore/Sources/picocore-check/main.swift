import PicoCore

run([
    ("Smoke", [
        Test("versionIsSet") {
            expectEqual(PicoCore.version, "0.2.0")
        },
    ]),
    dayDateTests,
    recurrenceTests,
    todoServiceTests,
    projectServiceTests,
    changeLogTests,
    parserTests,
    summaryTests,
    demoDataTests,
])
