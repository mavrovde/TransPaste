import Foundation

func runAppInfoTests() {
    test("app version is semantic and metadata is coherent") {
        let parts = AppInfo.version.split(separator: ".")
        expectEqual(parts.count, 3, "version must be MAJOR.MINOR.PATCH")
        expect(parts.allSatisfy { Int($0) != nil }, "version components must be numeric")
        expectNotNil(URL(string: AppInfo.repoURL), "repo URL must be valid")
        expectEqual(AppInfo.name, "TransPaste")
        expect(!AppInfo.author.isEmpty, "author must be set")
    }

    test("Info.plist version matches AppInfo.version") {
        // Info.plist lives at the repo root relative to the test binary's cwd
        guard let plist = try? String(contentsOfFile: "Info.plist", encoding: .utf8) else {
            skipNote("Info.plist not in cwd — run via ./test.sh from the repo root")
            return
        }
        expect(plist.contains("<string>\(AppInfo.version)</string>"),
               "Info.plist must carry AppInfo.version \(AppInfo.version) (build.sh keeps the bundle in sync)")
        expect(plist.contains("<key>CFBundleIconFile</key>"),
               "Info.plist must reference the generated AppIcon")
    }
}

private func skipNote(_ reason: String) {
    print("        note: \(reason)")
}
