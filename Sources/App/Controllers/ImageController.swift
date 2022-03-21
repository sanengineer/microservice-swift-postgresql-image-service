import Vapor
import Fluent


struct ImageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // let superUserMiddleware = SuperUserAuthMiddleware()
        // let midUserMiddleware = MidUserAuthMiddleware()
        // let userMiddleware = UserAuthMiddleware()
        let image = routes.grouped("image")
      
        // let imageAuthSuperUser = image.grouped(superUserMiddleware)
        // let imageAuthMidUser = image.grouped(midUserMiddleware)
        // let imageAuthUser = image.grouped(userMiddleware)
    
        // imageAuthUser.post(use: create)
        image.get(use: index)
        // image.post(use: create)
        image.on(.POST, body: .collect(maxSize: "10mb"), use: create)
       
    }

    func index(req: Request) throws -> EventLoopFuture<[Image]> {
        return Image.query(on: req.db).all()
    }


    func create(req: Request) throws -> EventLoopFuture<Response> {
        guard let authUrl = Environment.get("AUTH_URL") else {
            return req.eventLoop.future(error: Abort(.internalServerError))
        }
        guard let token = req.headers.bearerAuthorization else {
            return req.eventLoop.future(error: Abort(.unauthorized))
        }
        guard let storageImageUsername = Environment.get("STORAGE_IMAGE_USERNAME") else {
           return req.eventLoop.future(error: Abort(.unauthorized))
        }
        guard let storageImagePassword = Environment.get("STORAGE_IMAGE_PASSWORD") else {
           return req.eventLoop.future(error: Abort(.unauthorized))
        }
        guard let storageImageUrl = Environment.get("STORAGE_IMAGE_URL") else {
           return req.eventLoop.future(error: Abort(.unauthorized))
        }
        let image = try req.content.decode(ImageFile.self)
        let client_url: URI = "\(storageImageUrl)"
        guard image.file.data.capacity > 0 else {
            throw Abort(.badRequest, reason: "Image url is required")
        }
        let image_file = try req.content.decode(ImageFile.self)
        
        //debug
        // print("\nIMAGE: \(image.url.count)\n")
        // print("\nIMAGE FILE: \(image_file.file)\n")
        // print("\nCLIENT REQ: \(client_req)\n")
    
        return req
            .client
            .post("\(authUrl)/user/auth/authenticate", beforeSend: {
                authRequest in
                try authRequest.content.encode(AuthenticateData(token:token.token), as: .json)
            }).tryFlatMap{ response -> EventLoopFuture<Response> in
                let user = try response.content.decode(User.self)
                if response.status == .ok {
                    return req.client.post(client_url, beforeSend: { request in
                        let form = ImageFile(file: image_file.file, upload_preset: "unsigned_preset")
                        request.headers.basicAuthorization = .init(username: storageImageUsername, password: storageImagePassword)
                        try request.content.encode(form, as: .formData)
                        //debug
                        // print("\n", "FORM:", form, "\n")
                    }).tryFlatMap { response -> EventLoopFuture<Response> in
                        let _image = try response.content.decode(Image.self)
                        _image.user_id = user.id
                        //debug
                        // print("\n", "RESPONSE:", response.content , "\n")
                        // print("\n", "IMAGE:", _image, "\n")
                        if response.status == .ok {
                        return _image.save(on: req.db).tryFlatMap {
                            return req.eventLoop.makeSucceededFuture(.init(status: .ok, headers: ["Content-Type": "application/json"], body: "{\"message\": \"Image created successfully\"}"))
                            } 
                        } else {
                            if response.status == .unauthorized {
                                throw Abort(.unauthorized, reason: "UNAUTHORIZED")
                            } else {
                            throw Abort(.internalServerError)
                        }
                        }
                    }
                } else {
                    if response.status == .unauthorized {
                        throw Abort(.unauthorized, reason: "UNAUTHORIZED")
                    } else {
                        throw Abort(.internalServerError)
                    }
                }
            }
    }   
}