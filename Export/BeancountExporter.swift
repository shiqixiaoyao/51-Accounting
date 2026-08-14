import Foundation

/// 将交易导出为 Beancount 纯文本复式记账格式。
struct BeancountExporter {
    func export(_ transactions: [BookkeepingTransaction]) -> String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        return transactions.sorted { $0.date < $1.date }.map { transaction in
            let merchant = transaction.payee.replacingOccurrences(of: "\"", with: "'")
            let header = "\(formatter.string(from: transaction.date)) * \"\(merchant)\" \"\(transaction.note)\""
            let lines = transaction.postings.map { posting in "  \(posting.accountName)  \(posting.amount) \(transaction.currencyCode)" }
            return ([header] + lines).joined(separator: "\n")
        }.joined(separator: "\n\n") + "\n"
    }
}
