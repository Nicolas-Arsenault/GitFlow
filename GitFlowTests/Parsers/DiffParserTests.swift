import XCTest
@testable import GitFlow

final class DiffParserTests: XCTestCase {

    func testParseEmptyOutput() {
        let output = ""
        let diffs = DiffParser.parse(output)
        XCTAssertTrue(diffs.isEmpty)
    }

    func testParseSimpleDiff() {
        let output = """
        diff --git a/file.txt b/file.txt
        index abc123..def456 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,4 @@
         line1
        -old line
        +new line
        +added line
         line3
        """

        let diffs = DiffParser.parse(output)

        XCTAssertEqual(diffs.count, 1)

        let diff = diffs[0]
        XCTAssertEqual(diff.path, "file.txt")
        XCTAssertEqual(diff.changeType, .modified)
        XCTAssertFalse(diff.isBinary)
        XCTAssertEqual(diff.hunks.count, 1)

        let hunk = diff.hunks[0]
        XCTAssertEqual(hunk.oldStart, 1)
        XCTAssertEqual(hunk.oldCount, 3)
        XCTAssertEqual(hunk.newStart, 1)
        XCTAssertEqual(hunk.newCount, 4)

        // Count line types
        let context = hunk.lines.filter { $0.type == .context }
        let additions = hunk.lines.filter { $0.type == .addition }
        let deletions = hunk.lines.filter { $0.type == .deletion }

        XCTAssertEqual(context.count, 2)
        XCTAssertEqual(additions.count, 2)
        XCTAssertEqual(deletions.count, 1)
    }

    func testParseNewFile() {
        let output = """
        diff --git a/new.txt b/new.txt
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/new.txt
        @@ -0,0 +1,2 @@
        +line 1
        +line 2
        """

        let diffs = DiffParser.parse(output)

        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].changeType, .added)
        XCTAssertEqual(diffs[0].additions, 2)
        XCTAssertEqual(diffs[0].deletions, 0)
    }

    func testParseDeletedFile() {
        let output = """
        diff --git a/deleted.txt b/deleted.txt
        deleted file mode 100644
        index abc1234..0000000
        --- a/deleted.txt
        +++ /dev/null
        @@ -1,2 +0,0 @@
        -line 1
        -line 2
        """

        let diffs = DiffParser.parse(output)

        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].changeType, .deleted)
        XCTAssertEqual(diffs[0].additions, 0)
        XCTAssertEqual(diffs[0].deletions, 2)
    }

    func testParseBinaryFile() {
        let output = """
        diff --git a/image.png b/image.png
        index abc123..def456 100644
        Binary files a/image.png and b/image.png differ
        """

        let diffs = DiffParser.parse(output)

        XCTAssertEqual(diffs.count, 1)
        XCTAssertTrue(diffs[0].isBinary)
        XCTAssertTrue(diffs[0].hunks.isEmpty)
    }

    func testParseMultipleHunks() {
        let output = """
        diff --git a/file.txt b/file.txt
        index abc123..def456 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,3 @@ first function
         line1
        -old1
        +new1
         line3
        @@ -10,3 +10,3 @@ second function
         line10
        -old10
        +new10
         line12
        """

        let diffs = DiffParser.parse(output)

        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs[0].hunks.count, 2)

        XCTAssertEqual(diffs[0].hunks[0].header, "first function")
        XCTAssertEqual(diffs[0].hunks[1].header, "second function")
    }

    func testHunkHeaderParsing() {
        // Test various hunk header formats
        let cases = [
            ("@@ -1 +1 @@", (1, 1, 1, 1, "")),
            ("@@ -1,3 +1,4 @@", (1, 3, 1, 4, "")),
            ("@@ -10,5 +15,7 @@ func example()", (10, 5, 15, 7, "func example()")),
        ]

        for (header, expected) in cases {
            let result = DiffHunk.parseHeader(header)
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.oldStart, expected.0)
            XCTAssertEqual(result?.oldCount, expected.1)
            XCTAssertEqual(result?.newStart, expected.2)
            XCTAssertEqual(result?.newCount, expected.3)
            XCTAssertEqual(result?.header, expected.4)
        }
    }

    func testLineNumbers() {
        let output = """
        diff --git a/file.txt b/file.txt
        index abc123..def456 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -5,4 +5,5 @@
         context
        -deleted
        +added1
        +added2
         context2
        """

        let diffs = DiffParser.parse(output)
        let lines = diffs[0].hunks[0].lines

        // Context line: both old and new line numbers
        XCTAssertEqual(lines[0].oldLineNumber, 5)
        XCTAssertEqual(lines[0].newLineNumber, 5)

        // Deletion: only old line number
        XCTAssertEqual(lines[1].oldLineNumber, 6)
        XCTAssertNil(lines[1].newLineNumber)

        // Addition: only new line number
        XCTAssertNil(lines[2].oldLineNumber)
        XCTAssertEqual(lines[2].newLineNumber, 6)

        XCTAssertNil(lines[3].oldLineNumber)
        XCTAssertEqual(lines[3].newLineNumber, 7)

        // Final context
        XCTAssertEqual(lines[4].oldLineNumber, 7)
        XCTAssertEqual(lines[4].newLineNumber, 8)
    }
}
