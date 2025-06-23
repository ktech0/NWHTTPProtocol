//
//  HTTPMessage.swift
//  NWHTTPProtocol
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class Network.NWProtocolFramer

/// Message extensions to access the HTTPProtocol metadata, which are:
/// - method  (e.g. "GET")
/// - path    (e.g. "/vaca")
/// - status  (e.g. 402)
/// - headers (e.g. [ ( "Content-Type", "text/html" ),
///                   ( "ETag",         "42"        ) ])
/// - error
extension NWProtocolFramer.Message {

    public static var httpMessage: NWProtocolFramer.Message {
        .init(definition: HTTPProtocol.definition)
    }

    public convenience init(
        method: HTTPProtocol.Method = "GET",
        path: String,  // really a URI
        headers: HTTPProtocol.Headers = [],
        shouldKeepAlive: Bool = false
    ) {
        self.init(definition: HTTPProtocol.definition)
        self.method = method
        self.path = path
        self.headers = headers
        self.shouldKeepAlive = shouldKeepAlive
    }

    public convenience init(
        status: HTTPProtocol.Status,
        headers: HTTPProtocol.Headers = []
    ) {
        self.init(definition: HTTPProtocol.definition)
        self.status = status
        self.headers = headers
    }

    public var method: HTTPProtocol.Method? {
        set { self["http.method"] = newValue }
        get { self["http.method"] as? HTTPProtocol.Method }
    }

    public var path: String? {
        set { self["http.path"] = newValue }
        get { self["http.path"] as? String }
    }

    public var status: HTTPProtocol.Status? {
        set { self["http.status"] = newValue }
        get { self["http.status"] as? HTTPProtocol.Status }
    }

    public var headers: HTTPProtocol.Headers {
        set { self["http.headers"] = newValue }
        get { (self["http.headers"] as? HTTPProtocol.Headers) ?? [] }
    }

    public var isEndOfMessage: Bool {
        set { self["http.eom"] = newValue }
        get { (self["http.eom"] as? Bool) ?? false }
    }

    public var shouldKeepAlive: Bool {
        set { self["http.keepalive"] = newValue }
        get { (self["http.keepalive"] as? Bool) ?? false }
    }
}

extension NWProtocolFramer.Message {

    internal convenience init(error: HTTPProtocol.Error) {
        self.init(definition: HTTPProtocol.definition)
        self["http.error"] = error
    }

    /**
     * Contains a `HTTPProtocol.Error` if the parser failed.
     */
    public var error: HTTPProtocol.Error? {
        self["http.error"] as? HTTPProtocol.Error
    }
}
