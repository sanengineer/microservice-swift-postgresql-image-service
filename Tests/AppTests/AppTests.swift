@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    func testHelloWorld() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET,"",afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "hello vapor")
        })
        
        try app.test(.GET, "hello", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "hello route")
        })
        
        try app.test(.GET, "vapor",afterResponse: {res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "vapor route")
        })
        
        print(app)
    }
}