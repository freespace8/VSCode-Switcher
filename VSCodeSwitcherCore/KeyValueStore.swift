import Foundation

public protocol KeyValueStore {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? {
        storage[key]
    }

    public func set(_ data: Data?, forKey key: String) {
        storage[key] = data
    }
}

