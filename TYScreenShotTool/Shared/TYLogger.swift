import AuthenticationServices

enum TYLogger {
    
    static func debug(_ message: @autoclosure () -> String, tag: String? = nil, file: String = #file, line: Int = #line) {
        #if DEBUG
        let timestamp = Self.currentTimestamp()
        let fileName = (file as NSString).lastPathComponent
        let tagPart = tag.map { "[\($0)] " } ?? ""
        print("[DEBUG] \(timestamp) \(tagPart)\(message()) (\(fileName):\(line))")
        #endif
    }
    
    static func info(_ message: @autoclosure () -> String, tag: String? = nil) {
        #if DEBUG
        let timestamp = Self.currentTimestamp()
        let tagPart = tag.map { "[\($0)] " } ?? ""
        print("[INFO] \(timestamp) \(tagPart)\(message())")
        #endif
    }
    
    static func warn(_ message: @autoclosure () -> String, tag: String? = nil) {
        #if DEBUG
        let timestamp = Self.currentTimestamp()
        let tagPart = tag.map { "[\($0)] " } ?? ""
        print("[WARN] \(timestamp) \(tagPart)\(message())")
        #endif
    }
    
    static func error(_ message: @autoclosure () -> String, tag: String? = nil, error: Error? = nil) {
        #if DEBUG
        let timestamp = Self.currentTimestamp()
        let tagPart = tag.map { "[\($0)] " } ?? ""
        let errorPart = error.map { " (\($0.localizedDescription))" } ?? ""
        print("[ERROR] \(timestamp) \(tagPart)\(message())\(errorPart)")
        #endif
    }
    
    static func logAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        #if DEBUG
        print("[AI Pro Auth] Apple login credential received:")
        print("  - user: \(credential.user)")
        print("  - realUserStatus: \(credential.realUserStatus.rawValue)")
        print("  - hasState: \(credential.state?.isEmpty == false)")
        
        if let authorizationCodeData = credential.authorizationCode,
           let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) {
            print("  - authorizationCode: \(authorizationCode)")
        } else {
            print("  - authorizationCode: nil")
        }
        
        if let email = credential.email {
            print("  - email: \(email)")
        } else {
            print("  - email: nil (已登录过，Apple 不再返回)")
        }
        
        if let fullName = credential.fullName {
            print("  - fullName.givenName: \(fullName.givenName ?? "nil")")
            print("  - fullName.familyName: \(fullName.familyName ?? "nil")")
            print("  - fullName.nickname: \(fullName.nickname ?? "nil")")
            print("  - fullName.middleName: \(fullName.middleName ?? "nil")")
            print("  - fullName.namePrefix: \(fullName.namePrefix ?? "nil")")
            print("  - fullName.nameSuffix: \(fullName.nameSuffix ?? "nil")")
        } else {
            print("  - fullName: nil (已登录过，Apple 不再返回)")
        }
        
        if let identityTokenData = credential.identityToken,
           let identityToken = String(data: identityTokenData, encoding: .utf8) {
            print("  - identityToken (first 100 chars): \(identityToken.prefix(100))...")
        } else {
            print("  - identityToken: nil")
        }
        #endif
    }
    
    private static func currentTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
