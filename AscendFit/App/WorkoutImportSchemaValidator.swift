import Foundation
import CoreFoundation

/// Checks the same portable schema as the backend before Codable conversion.
/// Optional fields must be explicitly null; extra fields cannot be silently lost.
enum WorkoutImportSchemaValidator {
    static func validate(data: Data) throws {
        guard let url = Bundle.main.url(forResource: "workout-plan-v1.schema", withExtension: "json") else {
            throw WorkoutImportError.invalid("The workout format could not be loaded. Reopen the app and try again.")
        }
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        guard let schema else { throw WorkoutImportError.invalid("The workout format is unavailable.") }
        let value = try JSONSerialization.jsonObject(with: data)
        try check(value, against: schema, path: "", depth: 0)
    }

    private static func check(_ value: Any, against schema: [String: Any], path: String, depth: Int) throws {
        guard depth <= 64 else { throw invalid(path, "The JSON is too deeply nested.") }
        let supported: Set<String> = ["$schema", "$id", "title", "type", "anyOf", "enum", "properties", "required", "additionalProperties", "items", "minItems", "maxItems", "minLength", "maxLength", "pattern", "minimum", "maximum"]
        guard schema.keys.allSatisfy({ supported.contains($0) }) else {
            throw invalid(path, "This schema rule requires a newer app version.")
        }
        if let alternatives = schema["anyOf"] as? [[String: Any]] {
            for alternative in alternatives {
                do {
                    try check(value, against: alternative, path: path, depth: depth + 1)
                    return
                } catch { continue }
            }
            throw invalid(path, "Use the expected value type or null where allowed.")
        }
        if let type = schema["type"] as? String {
            let matches: Bool
            switch type {
            case "null": matches = value is NSNull
            case "object": matches = value is [String: Any]
            case "array": matches = value is [Any]
            case "string": matches = value is String
            case "boolean": matches = (value as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } ?? false
            case "number", "integer":
                if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                    let n = number.doubleValue
                    matches = n.isFinite && (type != "integer" || n.rounded() == n)
                } else { matches = false }
            default: throw invalid(path, "Unsupported format rule.")
            }
            guard matches else { throw invalid(path, "Expected \(type).") }
        }
        if let allowed = schema["enum"] as? [Any] {
            guard allowed.contains(where: { equal(value, $0) }) else { throw invalid(path, "Choose a supported value.") }
        }
        if let object = value as? [String: Any], let properties = schema["properties"] as? [String: [String: Any]] {
            for key in (schema["required"] as? [String] ?? []) where object[key] == nil {
                throw invalid(path + "/" + key, "This required field is missing; use null when the format allows it.")
            }
            if schema["additionalProperties"] as? Bool == false {
                if let extra = object.keys.sorted().first(where: { properties[$0] == nil }) {
                    throw invalid(path + "/" + extra, "This field is not part of WorkoutPlan v1.")
                }
            }
            for key in object.keys.sorted() {
                if let rule = properties[key], let child = object[key] {
                    try check(child, against: rule, path: path + "/" + key, depth: depth + 1)
                }
            }
        }
        if let array = value as? [Any] {
            if let minimum = schema["minItems"] as? Int, array.count < minimum { throw invalid(path, "Too few items.") }
            if let maximum = schema["maxItems"] as? Int, array.count > maximum { throw invalid(path, "Too many items.") }
            if let itemRule = schema["items"] as? [String: Any] {
                for (index, item) in array.enumerated() {
                    try check(item, against: itemRule, path: path + "/\(index)", depth: depth + 1)
                }
            }
        }
        if let text = value as? String {
            let count = text.unicodeScalars.count
            if let minimum = schema["minLength"] as? Int, count < minimum { throw invalid(path, "This text is too short.") }
            if let maximum = schema["maxLength"] as? Int, count > maximum { throw invalid(path, "This text is too long.") }
            if let pattern = schema["pattern"] as? String,
               text.range(of: pattern, options: .regularExpression) == nil { throw invalid(path, "This value has an invalid format.") }
        }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            if let minimum = schema["minimum"] as? NSNumber, number.doubleValue < minimum.doubleValue { throw invalid(path, "This value is below the allowed minimum.") }
            if let maximum = schema["maximum"] as? NSNumber, number.doubleValue > maximum.doubleValue { throw invalid(path, "This value is above the allowed maximum.") }
        }
    }

    private static func equal(_ lhs: Any, _ rhs: Any) -> Bool {
        if let a = lhs as? NSNumber, let b = rhs as? NSNumber {
            guard (CFGetTypeID(a) == CFBooleanGetTypeID()) == (CFGetTypeID(b) == CFBooleanGetTypeID()) else { return false }
            return a == b
        }
        if let a = lhs as? String, let b = rhs as? String { return a == b }
        return lhs is NSNull && rhs is NSNull
    }

    private static func invalid(_ path: String, _ message: String) -> WorkoutImportError {
        .invalid("\(path.isEmpty ? "Workout JSON" : path): \(message)")
    }
}
