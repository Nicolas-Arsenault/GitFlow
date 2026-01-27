import XCTest
@testable import GitFlow

final class LogParserTests: XCTestCase {

    func testParseEmptyOutput() throws {
        let output = ""
        let commits = try LogParser.parse(output)
        XCTAssertTrue(commits.isEmpty)
    }

    func testParseSingleCommit() throws {
        // Format: hash, shortHash, subject, body, authorName, authorEmail, authorDate, committerName, committerEmail, committerDate, parents
        let output = "abc123def456789012345678901234567890abcd\u{1E}abc123d\u{1E}Add new feature\u{1E}Detailed description\u{1E}John Doe\u{1E}john@example.com\u{1E}2024-01-15T10:30:00+00:00\u{1E}John Doe\u{1E}john@example.com\u{1E}2024-01-15T10:30:00+00:00\u{1E}parent123\u{1F}"

        let commits = try LogParser.parse(output)

        XCTAssertEqual(commits.count, 1)

        let commit = commits[0]
        XCTAssertEqual(commit.hash, "abc123def456789012345678901234567890abcd")
        XCTAssertEqual(commit.shortHash, "abc123d")
        XCTAssertEqual(commit.subject, "Add new feature")
        XCTAssertEqual(commit.body, "Detailed description")
        XCTAssertEqual(commit.authorName, "John Doe")
        XCTAssertEqual(commit.authorEmail, "john@example.com")
        XCTAssertEqual(commit.parentHashes, ["parent123"])
        XCTAssertFalse(commit.isMerge)
    }

    func testParseMergeCommit() throws {
        let output = "abc123def456789012345678901234567890abcd\u{1E}abc123d\u{1E}Merge branch 'feature'\u{1E}\u{1E}John Doe\u{1E}john@example.com\u{1E}2024-01-15T10:30:00+00:00\u{1E}John Doe\u{1E}john@example.com\u{1E}2024-01-15T10:30:00+00:00\u{1E}parent1 parent2\u{1F}"

        let commits = try LogParser.parse(output)

        XCTAssertEqual(commits.count, 1)
        XCTAssertTrue(commits[0].isMerge)
        XCTAssertEqual(commits[0].parentHashes, ["parent1", "parent2"])
    }

    func testParseMultipleCommits() throws {
        let commit1 = "hash1111111111111111111111111111111111111\u{1E}hash111\u{1E}First commit\u{1E}\u{1E}Author One\u{1E}one@example.com\u{1E}2024-01-15T10:00:00+00:00\u{1E}Author One\u{1E}one@example.com\u{1E}2024-01-15T10:00:00+00:00\u{1E}parent0"
        let commit2 = "hash2222222222222222222222222222222222222\u{1E}hash222\u{1E}Second commit\u{1E}\u{1E}Author Two\u{1E}two@example.com\u{1E}2024-01-14T09:00:00+00:00\u{1E}Author Two\u{1E}two@example.com\u{1E}2024-01-14T09:00:00+00:00\u{1E}hash111"

        let output = "\(commit1)\u{1F}\(commit2)\u{1F}"
        let commits = try LogParser.parse(output)

        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].subject, "First commit")
        XCTAssertEqual(commits[1].subject, "Second commit")
    }

    func testCommitProperties() {
        let commit = Commit(
            hash: "abc123def456789012345678901234567890abcd",
            shortHash: "abc123d",
            subject: "Fix bug in parser",
            body: "This fixes the issue with\nmultiline parsing",
            authorName: "Jane Smith",
            authorEmail: "jane@example.com",
            authorDate: Date(),
            parentHashes: ["parent123"]
        )

        XCTAssertEqual(commit.fullMessage, "Fix bug in parser\n\nThis fixes the issue with\nmultiline parsing")
        XCTAssertFalse(commit.isMerge)
        XCTAssertEqual(commit.id, commit.hash)
    }

    func testCommitWithEmptyBody() {
        let commit = Commit(
            hash: "abc123def456789012345678901234567890abcd",
            subject: "Simple commit",
            authorName: "Test",
            authorEmail: "test@example.com",
            authorDate: Date()
        )

        XCTAssertEqual(commit.fullMessage, "Simple commit")
    }
}
