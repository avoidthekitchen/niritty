import Foundation

public struct NirittyAppConfiguration: Equatable, Sendable {
    public var appWindowCount: Int
    public var appWindowTitle: String
    public var appWindowIdentifier: String

    public static let `default` = NirittyAppConfiguration(
        appWindowCount: 1,
        appWindowTitle: "Niritty",
        appWindowIdentifier: "workspace-stack"
    )
}
