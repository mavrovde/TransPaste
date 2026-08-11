import Foundation

// Intercepts all requests on a URLSession configured with this protocol class,
// so translate() can be tested without the network.
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (statusCode: Int, body: Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
            return
        }
        let (statusCode, body) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func mockedService() -> GoogleGeminiService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return GoogleGeminiService(session: URLSession(configuration: config))
}

private let testAPIKeyDefaultsKey = "GeminiAPIKey"

// Runs body with a known API key in UserDefaults, restoring the previous value after.
private func withTestAPIKey(_ body: () -> Void) {
    let previous = UserDefaults.standard.string(forKey: testAPIKeyDefaultsKey)
    UserDefaults.standard.set("TEST_KEY", forKey: testAPIKeyDefaultsKey)
    defer {
        if let previous = previous {
            UserDefaults.standard.set(previous, forKey: testAPIKeyDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: testAPIKeyDefaultsKey)
        }
    }
    body()
}

func runGoogleGeminiServiceTests() {
    let service = GoogleGeminiService()

    test("makeRequest sends API key as header, not in URL") {
        let request = service.makeRequest(text: "Hello", from: "English", to: "German", apiKey: "SECRET")
        expectNotNil(request)
        expectEqual(request?.httpMethod, "POST")
        expectEqual(request?.value(forHTTPHeaderField: "x-goog-api-key"), "SECRET")
        expectEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        expectEqual(
            request?.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent")
        expect(request?.url?.absoluteString.contains("SECRET") == false, "API key must not appear in the URL")
    }

    test("makeRequest builds explicit-language prompt") {
        let request = service.makeRequest(text: "Hello", from: "English", to: "German", apiKey: "K")
        guard let body = request?.httpBody,
              let decoded = try? JSONDecoder().decode(GeminiRequest.self, from: body),
              let prompt = decoded.contents.first?.parts.first?.text else {
            failTest("failed to decode request body")
            return
        }
        expect(prompt.contains("from English to German"), "prompt should name both languages")
        expect(prompt.contains("Hello"), "prompt should contain the source text")
    }

    test("makeRequest builds auto-detect prompt without source language") {
        let request = service.makeRequest(text: "Bonjour", from: "Auto", to: "English", apiKey: "K")
        guard let body = request?.httpBody,
              let decoded = try? JSONDecoder().decode(GeminiRequest.self, from: body),
              let prompt = decoded.contents.first?.parts.first?.text else {
            failTest("failed to decode request body")
            return
        }
        expect(!prompt.contains("from Auto"), "auto-detect prompt must not mention 'from Auto'")
        expect(prompt.contains("to English"), "prompt should name the target language")
    }

    if ProcessInfo.processInfo.environment["GEMINI_API_KEY"] != nil {
        skip("translate fails with noAPIKey when no key is configured",
             reason: "GEMINI_API_KEY is set in this environment")
    } else {
        test("translate fails with noAPIKey when no key is configured") {
            let previous = UserDefaults.standard.string(forKey: testAPIKeyDefaultsKey)
            UserDefaults.standard.removeObject(forKey: testAPIKeyDefaultsKey)
            defer {
                if let previous = previous {
                    UserDefaults.standard.set(previous, forKey: testAPIKeyDefaultsKey)
                }
            }

            var result: Result<String, TranslationError>?
            service.translate(text: "Hi", from: "En", to: "De") { result = $0 }
            waitUntil("completion") { result != nil }
            expectEqual(result?.failureError, .noAPIKey)
        }
    }

    test("translate returns trimmed translation on success") {
        withTestAPIKey {
            MockURLProtocol.handler = { _ in
                let json = """
                {"candidates": [{"content": {"parts": [{"text": "  Hallo Welt\\n"}]}}]}
                """
                return (200, Data(json.utf8))
            }
            var result: Result<String, TranslationError>?
            mockedService().translate(text: "Hello world", from: "English", to: "German") { result = $0 }
            waitUntil("completion") { result != nil }
            expectEqual(try? result?.get(), "Hallo Welt")
        }
    }

    test("translate surfaces API error message from response") {
        withTestAPIKey {
            MockURLProtocol.handler = { _ in
                (400, Data(#"{"error": {"message": "API key not valid"}}"#.utf8))
            }
            var result: Result<String, TranslationError>?
            mockedService().translate(text: "Hi", from: "En", to: "De") { result = $0 }
            waitUntil("completion") { result != nil }
            expectEqual(result?.failureError, .apiError("API Error: API key not valid"))
        }
    }

    test("translate reports apiError when candidates are missing") {
        withTestAPIKey {
            MockURLProtocol.handler = { _ in (200, Data("{}".utf8)) }
            var result: Result<String, TranslationError>?
            mockedService().translate(text: "Hi", from: "En", to: "De") { result = $0 }
            waitUntil("completion") { result != nil }
            expectEqual(result?.failureError, .apiError("No candidates returned"))
        }
    }

    test("translate reports apiError when candidate has no content (safety block)") {
        withTestAPIKey {
            MockURLProtocol.handler = { _ in
                (200, Data(#"{"candidates": [{"finishReason": "SAFETY"}]}"#.utf8))
            }
            var result: Result<String, TranslationError>?
            mockedService().translate(text: "Hi", from: "En", to: "De") { result = $0 }
            waitUntil("completion") { result != nil }
            expectEqual(result?.failureError, .apiError("No candidates returned"))
        }
    }

    test("translate reports decodingError on malformed JSON") {
        withTestAPIKey {
            MockURLProtocol.handler = { _ in (200, Data("not json".utf8)) }
            var result: Result<String, TranslationError>?
            mockedService().translate(text: "Hi", from: "En", to: "De") { result = $0 }
            waitUntil("completion") { result != nil }
            switch result?.failureError {
            case .decodingError:
                break
            default:
                failTest("expected decodingError, got \(String(describing: result))")
            }
        }
    }
}

private extension Result where Failure == TranslationError {
    var failureError: TranslationError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
