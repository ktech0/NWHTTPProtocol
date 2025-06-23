//
//  HTTPMethod.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public struct HTTPMethod: RawRepresentable, Hashable {

    public let rawValue: String

    @inlinable
    public init(rawValue string: String) { rawValue = string }
}

extension HTTPMethod: CustomStringConvertible {
    @inlinable
    public var description: String { return rawValue }
}

@inlinable
public func == (lhs: HTTPMethod, rhs: String) -> Bool {
    return lhs.rawValue == rhs
}
@inlinable
public func == (lhs: String, rhs: HTTPMethod) -> Bool {
    return lhs == rhs.rawValue
}

extension HTTPMethod {
    public static let GET: HTTPMethod = "GET"
    public static let POST: HTTPMethod = "POST"
    public static let MKCALENDAR: HTTPMethod = "MKCALENDAR"
    public static let DELETE: HTTPMethod = "DELETE"
    public static let HEAD: HTTPMethod = "HEAD"
    public static let PUT: HTTPMethod = "PUT"
    public static let CONNECT: HTTPMethod = "CONNECT"
    public static let OPTIONS: HTTPMethod = "OPTIONS"
    public static let TRACE: HTTPMethod = "TRACE"
    public static let COPY: HTTPMethod = "COPY"
    public static let LOCK: HTTPMethod = "LOCK"
    public static let MKCOL: HTTPMethod = "MKCOL"
    public static let MOVE: HTTPMethod = "MOVE"
    public static let PROPFIND: HTTPMethod = "PROPFIND"
    public static let PROPPATCH: HTTPMethod = "PROPPATCH"
    public static let SEARCH: HTTPMethod = "SEARCH"
    public static let UNLOCK: HTTPMethod = "UNLOCK"
    public static let REPORT: HTTPMethod = "REPORT"
    public static let MKACTIVITY: HTTPMethod = "MKACTIVITY"
    public static let CHECKOUT: HTTPMethod = "CHECKOUT"
    public static let MERGE: HTTPMethod = "MERGE"
    public static let MSEARCH: HTTPMethod = "MSEARCH"
    public static let NOTIFY: HTTPMethod = "NOTIFY"
    public static let SUBSCRIBE: HTTPMethod = "SUBSCRIBE"
    public static let UNSUBSCRIBE: HTTPMethod = "UNSUBSCRIBE"
    public static let PATCH: HTTPMethod = "PATCH"
    public static let PURGE: HTTPMethod = "PURGE"
}

extension HTTPMethod: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral string: String) { self.init(rawValue: string) }
}
