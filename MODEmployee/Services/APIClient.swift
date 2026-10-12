//
//  APIClient.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import Foundation

/// Centralized HTTP client for API communication
class APIClient {
    
    static let shared = APIClient()
    
    private let session: URLSession
    private let baseURL: String
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfig.apiTimeout
        configuration.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: configuration)
        self.baseURL = AppConfig.apiBaseURL
    }
    
    // MARK: - Generic Request Methods
    
    func performRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        requiresAuth: Bool = true,
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError(code: "INVALID_URL", message: "Invalid URL", details: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add authorization header if required
        if requiresAuth {
            if let token = KeychainService.shared.retrieveAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                throw APIError.unauthorized()
            }
        }
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError()
        }
        
        // Handle HTTP status codes
        try handleHTTPStatus(httpResponse.statusCode)
        
        // Decode response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if AppConfig.enableDebugLogging {
                print("Decoding error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "N/A")")
            }
            throw APIError(code: "DECODE_ERROR", message: "Failed to decode response", details: nil)
        }
    }
    
    func performMultipartRequest<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .post,
        fields: [String: String] = [:],
        imageData: Data,
        imageFieldName: String = "image",
        requiresAuth: Bool = true,
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError(code: "INVALID_URL", message: "Invalid URL", details: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add authorization header if required
        if requiresAuth {
            if let token = KeychainService.shared.retrieveAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                throw APIError.unauthorized()
            }
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add text fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(imageFieldName)\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform request
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError()
        }
        
        // Handle HTTP status codes
        try handleHTTPStatus(httpResponse.statusCode)
        
        // Decode response
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if AppConfig.enableDebugLogging {
                print("Decoding error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "N/A")")
            }
            throw APIError(code: "DECODE_ERROR", message: "Failed to decode response", details: nil)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleHTTPStatus(_ statusCode: Int) throws {
        switch statusCode {
        case 200...299:
            return
        case 400:
            throw APIError(code: "BAD_REQUEST", message: "Bad request", details: nil)
        case 401:
            throw APIError.unauthorized()
        case 403:
            throw APIError(code: "FORBIDDEN", message: "Forbidden", details: nil)
        case 404:
            throw APIError(code: "NOT_FOUND", message: "Resource not found", details: nil)
        case 409:
            throw APIError(code: "CONFLICT", message: "Conflict", details: nil)
        case 422:
            throw APIError(code: "UNPROCESSABLE_ENTITY", message: "Unprocessable entity", details: nil)
        case 429:
            throw APIError(code: "TOO_MANY_REQUESTS", message: "Too many requests", details: nil)
        case 500...599:
            throw APIError.serverError()
        default:
            throw APIError(code: "UNKNOWN_ERROR", message: "Unknown error", details: nil)
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
