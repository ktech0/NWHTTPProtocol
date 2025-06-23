//
//  HTTPContext.swift
//  NWHTTPProtocol
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class Network.NWConnection
import class Network.NWProtocolFramer

extension Optional where Wrapped == NWConnection.ContentContext {

    /**
     * Extract a HTTPProtocol Message from the context.
     *
     * Usage:
     *
     *     guard let message = context.httpMessage else {
     *         print("Connection closed ...")
     *         connection.cancel()
     *         return
     *     }
     *
     *     if let method = message.method {
     *         print("REQUEST:", method)
     *     }
     */
    public var httpMessage: NWProtocolFramer.Message? { self?.httpMessage }
}

extension NWConnection.ContentContext {

    /**
     * Extract a HTTPProtocol Message from the context.
     *
     * Usage:
     *
     *     guard let message = context?.httpMessage else {
     *         print("Connection closed...")
     *         connection.cancel()
     *         return
     *     }
     *
     *     if let method = message.method {
     *
     *     }
     */
    public var httpMessage: NWProtocolFramer.Message? {
        return protocolMetadata(definition: HTTPProtocol.definition)
            as? NWProtocolFramer.Message
    }
}
