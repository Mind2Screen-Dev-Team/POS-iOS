import Foundation

@main
struct App {
    static func main() async {
        print("POS iOS Service initialized.")
        print("API Base URL: \(EnvironmentConfig.baseURL)")
    }
}
