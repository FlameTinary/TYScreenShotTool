import Foundation

/// 创建隔离的 UserDefaults suite，避免测试污染本机配置。
extension UserDefaults {
    static func makeIsolated() -> UserDefaults {
        let name = "com.sheldon.TShot.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
