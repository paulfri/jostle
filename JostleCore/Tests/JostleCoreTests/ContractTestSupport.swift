import Foundation

func loadContractFixtures<T: Decodable>(
    _ type: T.Type,
    directory relativeDirectory: String
) throws -> [T] {
    var repositoryRoot = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 {
        repositoryRoot.deleteLastPathComponent()
    }
    let directory = repositoryRoot.appendingPathComponent(relativeDirectory, isDirectory: true)
    let URLs = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }
    let decoder = JSONDecoder()
    return try URLs.map { try decoder.decode(T.self, from: Data(contentsOf: $0)) }
}

func firstJSONDifference<T: Encodable>(
    expected: T,
    actual: T,
    path: String = "$"
) throws -> String? {
    let encoder = JSONEncoder()
    let expectedValue = try JSONSerialization.jsonObject(with: encoder.encode(expected))
    let actualValue = try JSONSerialization.jsonObject(with: encoder.encode(actual))
    return firstJSONDifference(expected: expectedValue, actual: actualValue, path: path)
}

private func firstJSONDifference(expected: Any, actual: Any, path: String) -> String? {
    if let expected = expected as? [String: Any], let actual = actual as? [String: Any] {
        let expectedKeys = expected.keys.sorted()
        let actualKeys = actual.keys.sorted()
        guard expectedKeys == actualKeys else {
            return "\(path): expected keys \(expectedKeys), actual keys \(actualKeys)"
        }
        for key in expectedKeys {
            if let difference = firstJSONDifference(
                expected: expected[key]!,
                actual: actual[key]!,
                path: "\(path).\(key)"
            ) {
                return difference
            }
        }
        return nil
    }

    if let expected = expected as? [Any], let actual = actual as? [Any] {
        guard expected.count == actual.count else {
            return "\(path): expected \(expected.count) items, actual \(actual.count) items"
        }
        for index in expected.indices {
            if let difference = firstJSONDifference(
                expected: expected[index],
                actual: actual[index],
                path: "\(path)[\(index)]"
            ) {
                return difference
            }
        }
        return nil
    }

    if let expected = expected as? NSNumber, let actual = actual as? NSNumber {
        if expected == actual {
            return nil
        }
        let floatingTypes = ["f", "d"]
        let usesFloatingPoint = floatingTypes.contains(String(cString: expected.objCType)) ||
            floatingTypes.contains(String(cString: actual.objCType))
        if usesFloatingPoint, abs(expected.doubleValue - actual.doubleValue) <= 1e-9 {
            return nil
        }
    } else if let expected = expected as? NSString, let actual = actual as? NSString,
              expected == actual {
        return nil
    } else if expected is NSNull, actual is NSNull {
        return nil
    }

    return "\(path): expected \(expected), actual \(actual)"
}
