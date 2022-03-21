import Fluent
import Vapor

final class Image: Model, Content, Codable {
    static let schema = "images"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "url")
    var secure_url: String?

    @Field(key: "asset_id")
    var asset_id: String?
    
    @Field(key: "public_id")
    var public_id: String?

    @Field(key:"signature")
    var signature: String?
    
    @Field(key: "user_id")
    var user_id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var created_at: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updated_at: Date?

    init() { }

    init(id: UUID? = nil,
         secure_url: String? = nil,
         asset_id: String? = nil,
         public_id: String? = nil,
         signature: String? = nil,
         user_id: UUID? = nil) {
        self.id = id
        self.secure_url = secure_url
        self.asset_id = asset_id
        self.public_id = public_id
        self.signature = signature
        self.user_id = user_id
    }
}

final class ImageFile: Content, Codable {
    var file: File
    var upload_preset: String?
   
    init(file: File, upload_preset: String?) {
        self.file = file
        self.upload_preset = upload_preset
    }
}


final class UpdateImage: Content, Codable {
    var url: String

    init(url: String) {
        self.url = url
    }
}