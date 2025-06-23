//
//  HTTPStatus.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public struct HTTPStatus: RawRepresentable, Hashable {
    public let rawValue: Int
    public init(rawValue status: Int) { self.rawValue = status }
}

extension HTTPStatus {
    public init(_ status: Int) { self.init(rawValue: status) }
}

extension HTTPStatus: ExpressibleByIntegerLiteral {
    public init(integerLiteral status: Int) { self.init(rawValue: status) }
}

extension HTTPStatus {

    public static let ok: HTTPStatus = 200
    public static let created: HTTPStatus = 201
    public static let noContent: HTTPStatus = 204

    public static let badRequest: HTTPStatus = 400
    public static let paymentRequired: HTTPStatus = 402
    public static let forbidden: HTTPStatus = 403
    public static let notFound: HTTPStatus = 404

    public static let serverError: HTTPStatus = 500
}
