import Foundation
import React
import AdServices
import NitroModules

class HybridNitroAppleAds: HybridNitroAppleAdsSpec {
    // MARK: - Constants
    static let errorDomain = "RNAAAErrorDomain"
    static let maxRetries = 3
    static let retryDelay: TimeInterval = 5.0
    static let apiUrl = "https://api-adservices.apple.com/api/v1/"

    // MARK: - Error Handling
    static func rejectPromiseWithNSError(_ reject: RCTPromiseRejectBlock, error: Error?) {
        if let error = error {
            let userInfo: [String: Any] = [
                "message": error,
                "nativeErrorCode": (error as NSError).code
            ]

            let enrichedError = NSError(
                domain: errorDomain,
                code: 100,
                userInfo: userInfo
            )

            reject("unknown", error.localizedDescription, enrichedError)
        } else {
            reject("unknown", "Failed with unknown error", nil)
        }
    }

    static func createError(description: String, code: Int = 100) -> NSError {
        return NSError(
            domain: errorDomain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }

    // MARK: - Environment Detection
    static func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func isAdServicesAvailable() -> Bool {
        if #available(iOS 14.3, *) {
            return true
        }
        return false
    }

    // MARK: - Token Handling
    static func getAdServicesAttributionToken() -> (token: String?, error: Error?) {
        if isSimulator() {
            return (nil, createError(description: "Error getting token, not available in Simulator"))
        }

        guard isAdServicesAvailable() else {
            return (nil, createError(description: "Error getting token, AdServices not available pre iOS 14.3"))
        }

        if #available(iOS 14.3, *) {
            do {
                let attributionToken = try AAAttribution.attributionToken()
                return (attributionToken, nil)
            } catch {
                return (nil, error)
            }
        }

        return (nil, createError(description: "Unexpected error in token generation"))
    }

    // MARK: - API Request
    @available(iOS 14.3, *)
    static func requestAdServicesAttributionDataUsingToken(
        _ token: String,
        retriesLeft: Int,
        completionHandler: @escaping ([String: Any]?, Error?) -> Void
    ) {
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = token.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, reqError in
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode != 200 {
                    if (statusCode == 404 || statusCode == 500) && retriesLeft > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                            self.requestAdServicesAttributionDataUsingToken(
                                token,
                                retriesLeft: retriesLeft - 1,
                                completionHandler: completionHandler
                            )
                        }
                        return
                    } else {
                        let errorMessage = "Request to get data from Adservices API failed with status code \(statusCode). Re-tried \(maxRetries - retriesLeft) times"
                        completionHandler(nil, createError(description: errorMessage))
                        return
                    }
                }
            }

            if let reqError = reqError {
                completionHandler(nil, reqError)
                return
            }

            guard let data = data else {
                completionHandler(nil, createError(description: "Request to Adservices API failed with unknown error"))
                return
            }

            do {
                if let attributionDataDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    completionHandler(attributionDataDictionary, nil)
                } else {
                    completionHandler(nil, createError(description: "Error parsing JSON data from AdServices API"))
                }
            } catch {
                completionHandler(nil, error)
            }
        }.resume()
    }

    // MARK: - Core Service Methods
    static func getAdServicesAttributionDataWithCompletionHandler(completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        guard isAdServicesAvailable() else {
            completionHandler(nil, createError(description: "AdServices not available pre iOS 14.3"))
            return
        }

        let (attributionToken, tokenError) = getAdServicesAttributionToken()

        if let attributionToken = attributionToken, #available(iOS 14.3, *) {
            requestAdServicesAttributionDataUsingToken(
                attributionToken,
                retriesLeft: maxRetries,
                completionHandler: completionHandler
            )
        } else {
            completionHandler(nil, tokenError)
        }
    }

    // MARK: - Public API
    func getAdServicesAttributionData(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        HybridNitroAppleAds.getAdServicesAttributionDataWithCompletionHandler { attributionData, error in
            if let attributionData = attributionData {
                resolve(attributionData)
            } else {
                HybridNitroAppleAds.rejectPromiseWithNSError(reject, error: error)
            }
        }
    }
}
