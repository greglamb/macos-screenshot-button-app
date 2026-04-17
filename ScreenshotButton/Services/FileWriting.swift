import Foundation

@MainActor
protocol FileWriting {
    func write(_ data: Data, to url: URL) throws
    func createDirectory(at url: URL) throws
}
