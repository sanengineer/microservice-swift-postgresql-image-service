import Vapor
import Fluent


struct ImageController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        let superUserMiddleware = SuperUserAuthMiddleware()
        let midUserMiddleware = MidUserAuthMiddleware()
        let userMiddleware = UserAuthMiddleware()
        let image = routes.grouped("image")
      
        let imageAuthSuperUser = image.grouped(superUserMiddleware)
        let imageAuthMidUser = image.grouped(midUserMiddleware)
        let imageAuthUser = image.grouped(userMiddleware)
    
        imageAuthMidUser.get(use: index)
        imageAuthMidUser.delete(use: delete)
        imageAuthUser.get(":user_id", use:indexByUserId)
        image.on(.POST, body: .collect(maxSize: "10mb"), use: create)
        imageAuthUser.on(.PUT, ":user_id", body: .collect(maxSize: "10mb"), use: updateByUserId)   
    }

    func index(req: Request) throws -> EventLoopFuture<[Image]> {
        return Image.query(on: req.db).all()
    }

    func indexByUserId(req: Request) throws -> EventLoopFuture<Image>{
        guard let user_id = req.parameters.get("user_id", as: UUID.self)  else {
            throw Abort(.badRequest)
        }
        let payload = try req.content.decode(ImageType.self)
        return Image.query(on: req.db)
                .filter(\.$user_id == user_id)
                .filter(\.$type == payload.type)
                .first().tryFlatMap({ (image) -> EventLoopFuture<Image> in
                    if let image = image {
                        return req.eventLoop.future(image)
                    } else {
                        throw Abort(.notFound)
                    }
                })
    }

    func updateByUserId(req: Request) throws -> EventLoopFuture<Response> {
        guard let user_id = req.parameters.get("user_id", as: UUID.self)  else {
            throw Abort(.badRequest)
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
        let image_type = try req.content.decode(ImageType.self)
        let client_url: URI = "\(storageImageUrl)"
        guard image.file.data.capacity > 0 else {
            throw Abort(.badRequest, reason: "Image url is required")
        }
        guard image_type.type.count > 0 else {
            throw Abort(.badRequest, reason: "Image type is required")
        }

        // let image_file = try req.content.decode(ImageFile.self)
        // let payload = try req.content.decode(ImageType.self)

        return req.client.post(client_url, beforeSend: { request in
            let form = ImageFile(file: image.file, upload_preset: "unsigned_preset")
            request.headers.basicAuthorization = .init(username: storageImageUsername, password: storageImagePassword)
            try request.content.encode(form, as: .formData)
            //debug
            print("\n", "FORM:", form, "\n")
            }).tryFlatMap { response -> EventLoopFuture<Response> in
                let _image = try response.content.decode(Image.self)
                _image.user_id = user_id
                _image.type = image_type.type
                //debug
                // print("\n", "RESPONSE:", response.content , "\n")
                print("\n", "IMAGE:", _image, "\n")

                if response.status == .ok {
                    return Image.query(on: req.db)
                        .filter(\.$user_id == user_id)
                        .filter(\.$type == image_type.type)
                        .first()
                        .tryFlatMap({ (image) -> EventLoopFuture<Response> in
                            if let image = image {
                                // print("\nRESULT:", image, "\n")

                                image.secure_url = _image.secure_url
                                image.public_id = _image.public_id
                                image.signature = _image.signature
                                image.updated_at = _image.created_at
                                image.asset_id = _image.asset_id
                                image.user_id = _image.user_id

                                return image.save(on: req.db).tryFlatMap {
                                    return req.eventLoop.makeSucceededFuture(
                                        .init(
                                            status: .ok, 
                                            headers: ["Content-Type": "application/json"], 
                                            body: "{\"message\": \"image updated successfully\"}"
                                        ))}      
                            } 
                            else {
                                throw Abort(.notFound)
                            }})
                } else {
                    if response.status == .unauthorized {
                        throw Abort(.unauthorized, reason: "UNAUTHORIZED")
                    } else {
                        throw Abort(.internalServerError)
                    }
                }
            }
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
        let image_type = try req.content.decode(ImageType.self)
        let client_url: URI = "\(storageImageUrl)"
        guard image.file.data.capacity > 0 else {
            throw Abort(.badRequest, reason: "Image url is required")
        }
        guard image_type.type.count > 0 else {
            throw Abort(.badRequest, reason: "Image type is required")
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
                        _image.type = image_type.type
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

    func delete(req: Request) throws -> EventLoopFuture<Response>{
        let payload = try req.content.decode(ImageDelete.self)

        return Image.query(on: req.db)
            .filter(\.$user_id == payload.user_id)
            .filter(\.$type == payload.type)
            .filter(\.$id == payload.id)
            .first()
            .tryFlatMap { image in
                if let image = image {
                    return image.delete(on: req.db).map {
                        return .init(status: .ok, headers: ["Content-Type": "application/json"], body: "{\"message\": \"Image deleted successfully\"}")
                    }
                } else {
                    throw Abort(.notFound)
                }
            }
    } 
}