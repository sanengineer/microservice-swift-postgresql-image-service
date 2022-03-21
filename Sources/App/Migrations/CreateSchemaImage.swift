import Fluent

struct CreateSchemaImage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("images")
            .id()
            .field("url", .string)
            .field("user_id", .uuid, .required)
            .field("asset_id", .string)
            .field("public_id",.string)
            .field("signature", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("images").delete()
    }
}