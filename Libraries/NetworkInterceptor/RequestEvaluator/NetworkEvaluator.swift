//
//  NetworkEvaluator.swift
//  UI Tests
//
//  Created by Bryan Dubno on 5/23/23.
//

import Foundation

public class NetworkConnectivityEvaluator: RequestEvaluator {
  public func isActionAllowed(urlRequest: URLRequest) -> Bool {
    // if we're not allowing network requests, we want this evaluator to return to return true so that the `MalformRequestRedirector` is used.
    return !Constants.currentTestOptions.allowNetworkRequests
  }
}
