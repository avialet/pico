import PicoCore

run([
    ("Smoke", [
        Test("versionIsSet") {
            expectEqual(PicoCore.version, "0.1.2")
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
