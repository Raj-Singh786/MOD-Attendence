//
//  KeychainService.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation
import Security

/// Service for secure storage of sensitive data in iOS Keychain
class KeychainService {
    
    static let shared = KeychainService()
    
    private let service = AppConfig.keychainServiceName
    
    private init() {}
    
    // MARK: - Generic Methods
    
    func store(_ value: String, forKey key: String) -> Bool {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else {
            print("Keychain error: \(status)")
            return false
        }
    }
    
    func retrieve(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Token Management
    
    func storeAccessToken(_ token: String) -> Bool {
        return store(token, forKey: AppConfig.keychainAccessTokenKey)
    }
    
    func retrieveAccessToken() -> String? {
        return retrieve(forKey: AppConfig.keychainAccessTokenKey)
    }
    
    func deleteAccessToken() -> Bool {
        return delete(forKey: AppConfig.keychainAccessTokenKey)
    }
    
    func storeRefreshToken(_ token: String) -> Bool {
        return store(token, forKey: AppConfig.keychainRefreshTokenKey)
    }
    
    func retrieveRefreshToken() -> String? {
        return retrieve(forKey: AppConfig.keychainRefreshTokenKey)
    }
    
    func deleteRefreshToken() -> Bool {
        return delete(forKey: AppConfig.keychainRefreshTokenKey)
    }
    
    // MARK: - Clear All
    
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
