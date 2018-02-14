/// Implementation of Search Ads attribution details
/// More info: https://searchads.apple.com/help/measure-results/#attribution-api

import Foundation
import iAd
import AutomatticTracks

@objc final class SearchAdsAttribution: NSObject {

    /// Keep the instance alive
    ///
    private static var lifeToken: SearchAdsAttribution?

    private static let userDefaultsSentKey = "search_ads_attribution_details_sent"
    private static let userDefaultsLimitedAdTrackingKey = "search_ads_limited_tracking"

    private let searchAdsApiVersion = "Version3.1"

    /// Is ad tracking limited?
    /// If the user has limited ad tracking, and this API won't return data
    ///
    private var isTrackingLimited: Bool {
        get {
            return UserDefaults.standard.bool(forKey: SearchAdsAttribution.userDefaultsLimitedAdTrackingKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SearchAdsAttribution.userDefaultsLimitedAdTrackingKey)
        }
    }

    /// Has the attribution details been sent already?
    /// Once the attribution details are sent, it won't change; so it is not necesary to send it again
    ///
    private var isAttributionDetailsSent: Bool {
        get {
            return UserDefaults.standard.bool(forKey: SearchAdsAttribution.userDefaultsSentKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: SearchAdsAttribution.userDefaultsSentKey)
        }
    }

    override init() {
        super.init()
        SearchAdsAttribution.lifeToken = self
    }

    @objc func requestDetails() {
        guard
            UIDevice.current.isSimulator() == false, // Requests from simulator will always fail
            isTrackingLimited == false,
            isAttributionDetailsSent == false
        else {
            finish()
            return
        }

        requestAttributionDetails()
    }

    private func requestAttributionDetails() {
        ADClient.shared().requestAttributionDetails { [weak self] (attributionDetails, error) in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.didReceiveError(error)
                } else {
                    self?.didReceiveAttributionDetails(attributionDetails)
                }
            }
        }
    }

    private func didReceiveAttributionDetails(_ details: [String: NSObject]?) {
        defer {
            finish()
        }
        guard let details = details?[searchAdsApiVersion] as? [String: Any] else {
            return
        }
        let parameters = sanitize(details)

        WPAnalytics.track(.searchAdsAttribution, withProperties: parameters)
        isAttributionDetailsSent = true
    }

    /// Fix key format to send to Tracks
    ///
    private func sanitize(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized = [String: String]()
        parameters.forEach {
            let key = $0.key.replacingOccurrences(of: "-", with: "_")
            let value: String = $0.value as? String ?? String(describing: $0.value)
            sanitized[key] = value
        }

        return sanitized
    }

    private func didReceiveError(_ error: Error) {
        let nsError = error as NSError

        guard nsError.code == ADClientError.Code.limitAdTracking.rawValue else {
            tryAgain(after: 5) // Possible connectivity issues
            return
        }

        // Not possible to get data
        isTrackingLimited = true
        finish()
    }

    private func tryAgain(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.requestDetails()
        }
    }

    /// Free this instance after all work is done.
    ///
    private func finish() {
        SearchAdsAttribution.lifeToken = nil
    }
}
