import Foundation

public enum TranslationError: Error, Equatable {
    case noAPIKey
    case invalidURL
    case networkError(NSError)
    case decodingError(NSError)
    case apiError(String)
    
    public static func == (lhs: TranslationError, rhs: TranslationError) -> Bool {
        switch (lhs, rhs) {
        case (.noAPIKey, .noAPIKey): return true
        case (.invalidURL, .invalidURL): return true
        case (.networkError(let e1), .networkError(let e2)): return e1.domain == e2.domain && e1.code == e2.code
        case (.decodingError(let e1), .decodingError(let e2)): return e1.domain == e2.domain && e1.code == e2.code
        case (.apiError(let s1), .apiError(let s2)): return s1 == s2
        default: return false
        }
    }
}

struct GeminiRequest: Codable {
    struct Content: Codable {
        struct Part: Codable {
            let text: String
        }
        let parts: [Part]
    }
    let contents: [Content]
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
            }
            let parts: [Part]?
        }
        // Optional: candidates blocked by safety filters arrive without content
        let content: Content?
    }
    let candidates: [Candidate]?
    let error: APIError?
    
    struct APIError: Codable {
        let message: String
    }
}

public class GoogleGeminiService {
    private let session: URLSession
    
    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }
    
    // Internal helper for testing - actually needs to be public if we test from another module
    public func makeRequest(text: String, from sourceLang: String, to targetLang: String, apiKey: String) -> URLRequest? {
        // Using 'gemini-flash-latest' as it was explicitly listed in the API capabilities for this key
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Header keeps the key out of URLs, which get logged by proxies and servers
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let prompt: String
        if sourceLang == "Auto" {
            prompt = "Translate the following text to \(targetLang). Only provide the translated text, no explanations or quotes:\n\n\(text)"
        } else {
            prompt = "Translate the following text from \(sourceLang) to \(targetLang). Only provide the translated text, no explanations or quotes:\n\n\(text)"
        }

        let body = GeminiRequest(contents: [.init(parts: [.init(text: prompt)])])
        guard let httpBody = try? JSONEncoder().encode(body) else { return nil }
        request.httpBody = httpBody

        return request
    }

    public func translate(text: String, from sourceLang: String, to targetLang: String, completion: @escaping (Result<String, TranslationError>) -> Void) {
        // Priority: 1. Environment Variable, 2. UserDefaults
        let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] 
                  ?? UserDefaults.standard.string(forKey: "GeminiAPIKey") 
                  ?? ""
        
        if apiKey.isEmpty {
            completion(.failure(.noAPIKey))
            return
        }
        
        guard let request = makeRequest(text: text, from: sourceLang, to: targetLang, apiKey: apiKey) else {
            completion(.failure(.invalidURL))
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error as NSError)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.apiError("No data received")))
                return
            }
            
            do {
                let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                
                if let apiError = geminiResponse.error {
                    let msg = "API Error: \(apiError.message)"
                    Logger.shared.log(msg)
                    completion(.failure(.apiError(msg)))
                    return
                }
                
                if let text = geminiResponse.candidates?.first?.content?.parts?.first?.text {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(.apiError("No candidates returned")))
                }
            } catch {
                completion(.failure(.decodingError(error as NSError)))
            }
        }
        
        task.resume()
    }
}
