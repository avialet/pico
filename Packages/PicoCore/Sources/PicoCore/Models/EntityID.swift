import Foundation
import GRDB

/// Identifiant d'entite : UUID stocke en texte, lisible par le CLI, les
/// scripts et la future sync.
public struct EntityID: Hashable, Sendable, Codable, CustomStringConvertible,
                        DatabaseValueConvertible, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public static func new() -> EntityID { EntityID(UUID().uuidString.lowercased()) }

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    public var databaseValue: DatabaseValue { rawValue.databaseValue }
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> EntityID? {
        String.fromDatabaseValue(dbValue).map { EntityID($0) }
    }
}
