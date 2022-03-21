import App
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)

//debug
// print("\n", app.routes , "\n")
// print(try configure(app), "\n")

try app.run()