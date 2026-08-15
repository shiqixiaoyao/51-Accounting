import XCTest
@testable import Accounting51

final class BackupOptionsTests: XCTestCase {
    func testLatestBackupAlwaysUsesStableFilename() {
        let filename = BackupFilename.webDAVFilename(
            scope: .transactionsOnly,
            target: .latest,
            snapshotName: "ignored",
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(filename, "51-accounting-backup-latest.json")
    }

    func testSnapshotFilenameNormalizesNameAndContainsScope() {
        let filename = BackupFilename.webDAVFilename(
            scope: .setupOnly,
            target: .snapshot,
            snapshotName: "月末 结账 / 重要",
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(filename, "51-accounting-setup-月末-结账---重要-19700101-000000.json")
    }

    func testEmptySnapshotNameUsesSafeFallback() {
        XCTAssertEqual(BackupFilename.normalizedSnapshotName("  "), "snapshot")
    }

    func testBackupSummaryReportsAllRecordCounts() {
        let backup = AccountingBackup(accounts: [], categories: [], transactions: [])
        XCTAssertEqual(DataTransferService.summary(for: backup), BackupSummary(exportedAt: backup.exportedAt, accountCount: 0, categoryCount: 0, transactionCount: 0, postingCount: 0))
    }
}
