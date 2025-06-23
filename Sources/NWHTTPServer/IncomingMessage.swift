//
//  IncomingMessage.swift
//  NWHTTPServer
//
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//
import Foundation
import NWHTTPProtocol

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONSerialization

struct MultipartFormDataPart {
    let name: String
    let filename: String?  // 如果是文件上传，则有文件名
    let contentType: String?  // 部分内容的 Content-Type
    let data: Data  // 部分的原始数据
}

enum MultipartParseError: Error {
    case invalidContentTypeHeader
    case missingBoundary
    case invalidBoundaryFormat
    case partParsingFailed
    case headerParsingFailed(String)
    case dispositionParsingFailed(String)
    case contentExtractionFailed
    case dataConversionFailed
}

extension String {
    // 辅助方法：去除前后引号
    func trimmingQuotes() -> String {
        guard self.hasPrefix("\"") && self.hasSuffix("\"") else { return self }
        return String(self.dropFirst().dropLast())
    }
}

// MARK: - Data 扩展 (修正 hasSuffix)

extension Data {
    // 修正后的 hasSuffix 方法
    func hasSuffix(_ suffix: Data) -> Bool {
        guard self.count >= suffix.count else { return false }
        return self.subdata(in: (self.count - suffix.count)..<self.count) == suffix
    }

    // 用于按 Data 分割的辅助函数
    func components(separatedBy separator: Data) -> [Data] {
        var components: [Data] = []
        var searchRange = self.startIndex..<self.endIndex

        while let range = self.range(of: separator, options: [], in: searchRange) {
            components.append(self.subdata(in: searchRange.lowerBound..<range.lowerBound))
            searchRange = range.upperBound..<self.endIndex
        }
        components.append(self.subdata(in: searchRange))
        return components
    }
}

/// Represents an incoming HTTP message.
///
/// This can be both, a Request or a Response - it is a Response when it got
/// created by a client and it is a Request if it is coming from the Server.
///
/// The content of the message can be either streamed to the client,
/// or if no data callback is set, it will get buffered within the
/// object.
/// In both cases one needs to wait for `end`!
///
/// Content Buffering:
///
///     let server = try HTTPServer { request, response in
///         print("Request:", request)
///         request.onEnd {
///             print("received content:", request.content)
///             response.send("OK, got it!\n")
///         }
///     }
///
/// Content Streaming:
///
///     let server = try HTTPServer { request, response in
///         print("Request:", request)
///         request.onData { data in
///             print("received data chunk:", data)
///         }
///         request.onEnd {
///             response.send("OK, got it!\n")
///         }
///     }
open class IncomingMessage: CustomStringConvertible {
    // Most is marked `open` in case the consumer wants to patch stuff in a
    // subclass.

    public enum IncomingType {
        case request(method: HTTPMethod, path: String)
        case response(status: HTTPStatus)
    }

    open var messageType: IncomingType
    open var headers: HTTPProtocol.Headers
    open var bufferedData = Data()
    open var readableEnded = false
    open var formFields: [String: String] = [:]
    open var uploadedFiles: [String: (name: String, data: Data)] = [:]

    open var _errorCB: ((Swift.Error) -> Void)?
    open var _dataCB: ((Data) -> Void)?
    open var _endCB: (() -> Void)?

    public init(
        method: HTTPMethod, path: String,
        headers: HTTPProtocol.Headers = []
    ) {
        self.messageType = .request(method: method, path: path)
        self.headers = headers
    }
    public init(status: HTTPStatus, headers: HTTPProtocol.Headers = []) {
        self.messageType = .response(status: status)
        self.headers = headers
    }

    // MARK: - Callbacks

    /**
     * Register a callback to be executed when content is received. When a
     * callback is set, the buffer won't get filled.
     *
     * If data was accumulated already, it will be flushed to that closure.
     *
     * Example:
     *
     *     request.onData { data in
     *         print("received data chunk:", data)
     *     }
     *
     */
    open func onData(execute: @escaping (Data) -> Void) {
        _dataCB = execute
        flush()  // TBD: async?
    }

    /**
     * Register a callback to be executed when the request has been retrieved
     * completely, i.e. all body data has been read.
     */
    open func onEnd(execute: @escaping () -> Void) {
        guard !readableEnded else { return execute() }  // TBD: async?
        _endCB = execute
    }

    /**
     * Register a callback to be executed when request specific errors arrive.
     * If none is set, errors will be sent to the HTTPserver error handler.
     */
    open func onError(execute: @escaping (Swift.Error) -> Void) {
        _errorCB = execute
    }

    internal func emitError(_ error: Swift.Error) -> Bool {
        guard let cb = _errorCB else { return false }
        cb(error)
        return true
    }

    // MARK: - Receiving Body Data

    private func flush() {
        guard let dataCB = _dataCB else { return }
        guard !bufferedData.isEmpty else { return }
        let data = bufferedData
        bufferedData = Data()
        dataCB(data)
    }
    private func invalidate() {
        _dataCB = nil
        _endCB = nil
        _errorCB = nil
    }

    /**
     * Push new body data into the request. Push `nil` for end-of-message.
     */
    open func push(_ data: Data?) {
        assert(!readableEnded)
        guard !readableEnded else { return }

        guard let data = data else {  // EOF
            readableEnded = true
            flush()
            _endCB?()
            return invalidate()
        }

        if let dataCB = _dataCB {
            flush()
            dataCB(data)
        } else {
            bufferedData.append(data)
        }
    }

    // MARK: - Content Accessors (when used w/o a callback)

    /**
     * Returns all body data buffered so far. Note that this will be empty at the
     * time the HTTPServer handler is invoked!
     * To wait for all content to arrive in the buffer, use the `onEnd` callback.
     *
     * Example:
     *
     *     request.onEnd {
     *         print("received content:", request.content)
     *     }
     *
     * No data will be buffered if the user has installed an `onData` handler.
     */
    open var content: Data {
        return bufferedData
    }

    /**
     * Returns all body data buffered so far. Note that this will be empty at the
     * time the HTTPServer handler is invoked!
     * To wait for all content to arrive in the buffer, use the `onEnd` callback.
     *
     * This variant tries to return the content as an UTF-8 string. If a
     * conversion to UTF-8 fails, an error will be emitted and nil will be
     * returned.
     *
     * Example:
     *
     *     request.onEnd {
     *         print("received content:", request.contentAsString ?? "-")
     *     }
     *
     * No data will be buffered if the user has installed an `onData` handler.
     */
    open var contentAsString: String? {
        // TODO: scan for charset in headers :-)
        guard !content.isEmpty else { return "" }
        guard let s = String(data: content, encoding: .utf8) else {
            _errorCB?(StringEncodingError(encoding: .utf8))
            return nil
        }
        return s
    }

    /**
     * Returns all body data buffered so far. Note that this will be empty at the
     * time the HTTPServer handler is invoked!
     * To wait for all content to arrive in the buffer, use the `onEnd` callback.
     *
     * This variant tries to parse the content as JSON into a Decodable type
     * provided.
     *
     * Example:
     *
     *     struct Entry: Codable {
     *       let date  : Date
     *       let title : String
     *       let body  : String
     *     }
     *
     *     request.onEnd {
     *         guard let entry = try? request.decodeJSON(as: Entry.self) else {
     *             response.writeHead(status: badRequest)
     *             response.end()
     *             return
     *         }
     *         print("received entry:", entry)
     *         response.send("got entry!")
     *     }
     *
     * No data will be buffered if the user has installed an `onData` handler.
     */
    open func decodeJSON<T: Decodable>(as type: T.Type) throws -> T {
        return try JSONDecoder().decode(type, from: content)
    }

    /**
     * Returns all body data buffered so far. Note that this will be empty at the
     * time the HTTPServer handler is invoked!
     * To wait for all content to arrive in the buffer, use the `onEnd` callback.
     *
     * This variant tries to parse the content as JSON into property list values.
     *
     * Example:
     *
     *     request.onEnd {
     *         guard let entry = try? request.decodeJSON()
     *                       as? [ String : String] else
     *         {
     *             response.writeHead(status: badRequest)
     *             response.end()
     *             return
     *         }
     *         print("received entry:", entry)
     *         response.send("got entry!")
     *     }
     *
     * No data will be buffered if the user has installed an `onData` handler.
     */
    open func decodeJSON(options: JSONSerialization.ReadingOptions = []) throws -> Any {
        return try JSONSerialization.jsonObject(with: content, options: options)
    }

    // MARK: - HTTP Requests

    @inlinable
    public var method: HTTPMethod {
        guard case .request(let method, _) = messageType else { return "" }
        return method
    }

    @inlinable
    public var url: String {
        guard case .request(_, let path) = messageType else { return "" }
        return path
    }

    @inlinable
    public var statusCode: Int {
        guard case .response(let status) = messageType else { return 0 }
        return status.rawValue
    }

    /// 解析multipart/form-data类型的请求体，提取表单字段和上传文件
    /// - Example:
    /// ```
    /// if try req.parseMultipartFormData(), let path = req.formFields["path"], var dir = permitted(URL(string: path)) {
    ///     for (_, file) in req.uploadedFiles {
    ///         let filePath = dir.appending(component: file.name)
    ///         try file.data.write(to: filePath)
    ///         print("Saved file: \(filePath.path(percentEncoded: false))")
    ///     }
    /// }
    /// ```
    /// - Returns: true if parse success
    open func parseMultipartFormData() throws -> Bool {

        // 1. 验证Content-Type头并提取boundary分隔符
        // multipart/form-data格式要求Content-Type包含boundary参数
        guard let contentTypeHeader = headers.first(where: { $0.name.lowercased() == "content-type" }) else {
            throw MultipartParseError.invalidContentTypeHeader
        }

        let contentTypeComponents = contentTypeHeader.value.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let mainContentType = contentTypeComponents.first, mainContentType.lowercased() == "multipart/form-data" else {
            throw MultipartParseError.invalidContentTypeHeader
        }

        guard let boundaryParameter = contentTypeComponents.first(where: { $0.starts(with: "boundary=") }) else {
            throw MultipartParseError.missingBoundary
        }

        let boundary = String(boundaryParameter.dropFirst("boundary=".count))

        // 2. 定义标准分隔符的 Data 形式
        // 每个部分以 `--<boundary>\r\n` 开头
        // 最后一个部分以 `--<boundary>--\r\n` 结束
        guard let partBoundaryData = "--\(boundary)\r\n".data(using: .utf8),
            let endBoundaryData = "--\(boundary)--\r\n".data(using: .utf8),
            let lineFeedData = "\r\n".data(using: .utf8),                // CRLF 换行符
            let doubleLineFeedData = "\r\n\r\n".data(using: .utf8)       // 头部和内容之间的空行
        else {
            throw MultipartParseError.invalidBoundaryFormat
        }

        var currentOffset = 0
        let requestBody = content  // 使用原始 Data

        // 跳过数据开头可能存在的空部分或前导 CRLF
        // 查找第一个真正的部分边界
        guard let initialBoundaryRange = requestBody.range(of: partBoundaryData, options: [], in: currentOffset..<requestBody.count) else {
            throw MultipartParseError.missingBoundary
        }
        currentOffset = initialBoundaryRange.upperBound  // 更新偏移量到第一个边界之后

        while currentOffset < requestBody.count {
            // 查找下一个边界（可能是部分边界或结束边界）
            guard let nextBoundaryRange = requestBody.range(of: partBoundaryData, options: [], in: currentOffset..<requestBody.count)
                    ?? requestBody.range(of: endBoundaryData, options: [], in: currentOffset..<requestBody.count) else {
                // 如果找不到任何边界，且当前不是结束边界，则数据格式错误
                if !requestBody[currentOffset..<requestBody.count].isEmpty {
                    throw MultipartParseError.partParsingFailed
                }
                break  // 已经到达数据末尾，或已处理完所有部分
            }

            // 提取当前部分的数据（包括头部和内容）
            var partRawData = requestBody.subdata(in: currentOffset..<nextBoundaryRange.lowerBound)

            // 数据部分末尾在边界前会有一个 CRLF，需要移除末尾的 CRLF
            if partRawData.hasSuffix(lineFeedData) {
                partRawData.removeLast(lineFeedData.count)
            }

            // 查找头部和内容之间的空行
            guard let headerEndRange = partRawData.range(of: doubleLineFeedData, options: [], in: 0..<partRawData.count) else {
                throw MultipartParseError.headerParsingFailed("Missing header-content separator")
            }

            let headerData = partRawData.subdata(in: 0..<headerEndRange.lowerBound)
            let contentData = partRawData.subdata(in: headerEndRange.upperBound..<partRawData.count)

            // parse Content Header
            var partHeaders: [String: String] = [:]
            let headerLines = headerData.components(separatedBy: lineFeedData)
            for lineData in headerLines {
                guard let lineString = String(data: lineData, encoding: .utf8) else {
                    throw MultipartParseError.headerParsingFailed("Invalid header line encoding")
                }
                let trimmedLine = lineString.trimmingCharacters(in: .whitespacesAndNewlines)
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    let key = String(trimmedLine[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                    let value = String(trimmedLine[trimmedLine.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    partHeaders[key] = value
                }
            }

            // parse Content-Disposition
            guard let dispositionString = partHeaders["content-disposition"], dispositionString.starts(with: "form-data") else {
                throw MultipartParseError.dispositionParsingFailed("Missing or invalid Content-Disposition")
            }

            var name: String?
            var filename: String?
            let dispositionComponents = dispositionString.components(separatedBy: ";").map {
                $0.trimmingCharacters(in: .whitespaces)
            }

            for component in dispositionComponents {
                if component.starts(with: "name=") {
                    name = String(component.dropFirst("name=".count)).trimmingQuotes()
                } else if component.starts(with: "filename=") {
                    filename = String(component.dropFirst("filename=".count)).trimmingQuotes()
                }
            }

            guard let fieldName = name, !fieldName.isEmpty else {
                throw MultipartParseError.dispositionParsingFailed("Missing field name in Content-Disposition")
            }
            // get content-type
            //let partContentType = partHeaders["content-type"]

            // 处理解析出的部分
            if let fn = filename, !fn.isEmpty {
                uploadedFiles[fn] = (name: fn, data: contentData)
            } else {
                // 文本字段，尝试转换为字符串
                if let textContent = String(data: contentData, encoding: .utf8) {
                    formFields[fieldName] = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    print("Warning: Could not decode text content for field '\(fieldName)'. Storing raw data if needed.")
                }
            }

            currentOffset = nextBoundaryRange.upperBound  // 更新偏移量到下一个边界之后
        }

        return true
    }
    
    open var description: String {
        var ms: String = "<"

        switch messageType {
        case .request(let method, let path):
            ms += method.rawValue + ": " + path
        case .response(let status):
            ms += "\(status)"
        }

        headers.forEach { (name, value) in
            ms += " " + name + "=" + value
        }

        ms += ">"
        return ms
    }
}
