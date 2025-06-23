#!/usr/bin/swift

import NWHTTPServer
import Foundation
import Network

class PermURL: Codable {
    var url: URL
    var bookmark: Data // url permission bookmark
    
    enum CodingKeys: String, CodingKey {
        case url
        case bookmark
    }
}
class FileServer: ObservableObject {
    let port: UInt16 = 1234
    let server: HTTPServer
    
    init(rootPermURLs: [PermURL]) throws {
        let router = WebRouter(rootPermURLs: rootPermURLs)
        server = try HTTPServer(port: NWEndpoint.Port(rawValue: port)!){req, res in
            req.onEnd { router.execute(req: req, res: res) }
        }
    }
    
    func start() {
        server.resume()
    }
    
    func stop() {
        server.suspend()
    }
}


class WebRouter {
    let controller: WebController
    let rootPermURLs: [PermURL]
    let route: [URL: (IncomingMessage, ServerResponse) -> Void]
    
    init(rootPermURLs: [PermURL]) {
        self.rootPermURLs = rootPermURLs
        self.controller = WebController(rootPermURLs: self.rootPermURLs)
        self.route = [
            URL(string: "/download")!: controller.download, // route download
            URL(string: "/upload")!: controller.upload,     // route upload
        ]
    }
    
    func execute(req: IncomingMessage, res: ServerResponse) {
        if let path = URL(string: req.url) {
            for (k, fn) in self.route {
                if path.pathComponents.starts(with: k.pathComponents) {
                    fn(req, res)
                    return
                }
            }
        }
        // route index
        controller.index(req: req, res: res)
    }
}

class WebController {
    let rootPermURLs: [PermURL]
    let path: URL = URL(filePath: Bundle.main.resourcePath!)
    
    init(rootPermURLs: [PermURL]) {
        self.rootPermURLs = rootPermURLs
    }
    
    func index(req: IncomingMessage, res: ServerResponse) {
        _ = res.sendFile(atPath: path.appending(component: "index.html").path(percentEncoded: false))
    }
    
    func upload(req: IncomingMessage, res: ServerResponse) {
        do {
            if try req.parseMultipartFormData(), let path = req.formFields["path"], var dir = URL(string: path) {
                dir = try permitted(rootPermURLs: rootPermURLs, url: dir)
                for (_, file) in req.uploadedFiles {
                    let filePath = dir.appending(component: file.name)
                    try file.data.write(to: filePath)
                    print("Saved file: \(filePath.path(percentEncoded: false))")
                }
                _responseJson(res: res, data: "Files uploaded successfully (\(req.uploadedFiles.count))")
            } else {
                _responseJson(res: res, data: "Invalid multipart/form-data request", status: .badRequest)
            }
        } catch {
            _responseJson(res: res, data: error.localizedDescription, status: .badRequest)
        }
    }
    
    func download(req: IncomingMessage, res: ServerResponse) {
        do {
            let params = try _parseParams(req: req)
            if let path = params["path"], !path.isEmpty {
                _ = res.sendFile(atPath: path)
            } else {
                throw "need params: 'path'" as! any Error
            }
        } catch {
            _responseJson(res: res, data: error.localizedDescription, status: .badRequest)
        }
    }
    
    private func _parseParams(req: IncomingMessage) throws -> [String: String] {
        guard let url: URL = URL(string: req.url) else { return ["": ""] }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var params: [String: String] = [:]
        if let queryItems = components?.queryItems {
            for item in queryItems {
                params[item.name] = item.value
            }
        }
        return params
    }
    
    private func _responseJson(res: ServerResponse, data: Codable, status: HTTPStatus = .ok) {
        let x = try! JSONEncoder().encode(data)
        res.writeHead(status: status, headers: [
            "Content-Type": "application/json; charset=UTF-8",
            "Content-Length": "\(x.count)",
        ])
        res.send(x)
    }
}