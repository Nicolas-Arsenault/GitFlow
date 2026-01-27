import XCTest
@testable import GitFlow

final class StatusParserTests: XCTestCase {

    func testParseEmptyOutput() {
        let output = ""
        let files = StatusParser.parse(output)
        XCTAssertTrue(files.isEmpty)
    }

    func testParseModifiedFile() {
        // Porcelain format with -z: XY path\0
        let output = " M src/file.swift\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].path, "src/file.swift")
        XCTAssertNil(files[0].indexStatus)
        XCTAssertEqual(files[0].workTreeStatus, .modified)
        XCTAssertFalse(files[0].isStaged)
        XCTAssertTrue(files[0].isUnstaged)
    }

    func testParseStagedFile() {
        let output = "M  src/staged.swift\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].path, "src/staged.swift")
        XCTAssertEqual(files[0].indexStatus, .modified)
        XCTAssertNil(files[0].workTreeStatus)
        XCTAssertTrue(files[0].isStaged)
        XCTAssertFalse(files[0].isUnstaged)
    }

    func testParseUntrackedFile() {
        let output = "?? new-file.txt\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].path, "new-file.txt")
        XCTAssertEqual(files[0].indexStatus, .untracked)
        XCTAssertEqual(files[0].workTreeStatus, .untracked)
        XCTAssertTrue(files[0].isUntracked)
    }

    func testParseAddedFile() {
        let output = "A  new-feature.swift\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].indexStatus, .added)
        XCTAssertTrue(files[0].isStaged)
    }

    func testParseDeletedFile() {
        let output = "D  removed.swift\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].indexStatus, .deleted)
    }

    func testParseMultipleFiles() {
        let output = "M  staged.swift\0 M unstaged.swift\0?? untracked.txt\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].path, "staged.swift")
        XCTAssertEqual(files[1].path, "unstaged.swift")
        XCTAssertEqual(files[2].path, "untracked.txt")
    }

    func testParseBothStagedAndUnstaged() {
        let output = "MM both-modified.swift\0"
        let files = StatusParser.parse(output)

        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].indexStatus, .modified)
        XCTAssertEqual(files[0].workTreeStatus, .modified)
        XCTAssertTrue(files[0].isStaged)
        XCTAssertTrue(files[0].isUnstaged)
    }

    func testFileStatusProperties() {
        let file = FileStatus(
            path: "src/components/Button.swift",
            indexStatus: .modified,
            workTreeStatus: nil,
            originalPath: nil
        )

        XCTAssertEqual(file.fileName, "Button.swift")
        XCTAssertEqual(file.directory, "src/components")
        XCTAssertTrue(file.isStaged)
        XCTAssertFalse(file.isUnstaged)
        XCTAssertFalse(file.isUntracked)
        XCTAssertFalse(file.hasConflict)
    }
}
