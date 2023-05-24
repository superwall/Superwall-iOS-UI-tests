//
//  MalformRequestRedirector.swift
//  UI Tests
//
//  Created by Bryan Dubno on 5/23/23.
//

import Foundation

public class MalformRequestRedirector: RedirectableRequestHandler {

  init(){}

  public func redirectedRequest(originalUrlRequest: URLRequest) -> URLRequest {
    // Always allow UI test communication
    guard originalUrlRequest.url?.absoluteString.contains("localhost") == false else {
      return originalUrlRequest
    }

    // Malform the request
    var request = originalUrlRequest
    request.httpMethod = "MALFORMED"
    return request
  }
}
