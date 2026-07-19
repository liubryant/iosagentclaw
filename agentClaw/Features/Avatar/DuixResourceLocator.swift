import Foundation

struct DuixResourcePaths {
    let baseModelPath: String
    let digitalModelPath: String
}

enum DuixResourceLocator {
    static func lilyPaths(in bundle: Bundle = .main) -> DuixResourcePaths? {
        guard
            let baseURL = bundle.url(forResource: "gj_dh_res", withExtension: nil, subdirectory: "duix"),
            let lilyURL = bundle.url(forResource: "Lily", withExtension: nil, subdirectory: "duix")
        else {
            return nil
        }
        return DuixResourcePaths(baseModelPath: baseURL.path, digitalModelPath: lilyURL.path)
    }
}
