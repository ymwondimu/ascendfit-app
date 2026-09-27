import Foundation
import Testing
@testable import AscendFit

private final class ImportFixtureBundle: NSObject {}

struct WorkoutImportSchemaTests {
    @Test("The standardized Lower A file passes the bundled schema; missing, extra, wrong-type and future fields fail")
    func strictPortableFormat() throws {
        let bundle = Bundle(for: ImportFixtureBundle.self)
        let url = try #require(bundle.url(forResource: "lower-a-ready.workout", withExtension: "json"))
        let data = try Data(contentsOf: url)
        try WorkoutImportSchemaValidator.validate(data: data)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let original = try #require(decoded)
        var extra = original
        extra["unrecognizedPlanOption"] = true
        #expect(throws: WorkoutImportError.self) { try WorkoutImportSchemaValidator.validate(data: JSONSerialization.data(withJSONObject: extra)) }
        var future = original
        future["schemaVersion"] = 2
        #expect(throws: WorkoutImportError.self) { try WorkoutImportSchemaValidator.validate(data: JSONSerialization.data(withJSONObject: future)) }
        var missing = original
        missing.removeValue(forKey: "confidence")
        #expect(throws: WorkoutImportError.self) { try WorkoutImportSchemaValidator.validate(data: JSONSerialization.data(withJSONObject: missing)) }
        var wrongType = original
        wrongType["schemaVersion"] = true
        #expect(throws: WorkoutImportError.self) { try WorkoutImportSchemaValidator.validate(data: JSONSerialization.data(withJSONObject: wrongType)) }
    }
}
