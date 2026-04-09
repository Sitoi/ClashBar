import Foundation

struct SettingsPortField: Equatable {
    let key: String
    let value: String
}

enum BuildPortPatchBodyError: Error, Equatable {
    case invalidPort(key: String)
}

struct BuildPortPatchBodyUseCase {
    func execute(
        fields: [SettingsPortField],
        skipEmptyValues: Bool) throws -> [String: ConfigPatchValue]
    {
        var body: [String: ConfigPatchValue] = [:]

        for field in fields {
            let trimmedValue = field.value.trimmed
            if skipEmptyValues, trimmedValue.isEmpty {
                continue
            }

            guard let intValue = Int(trimmedValue), (0...65535).contains(intValue) else {
                throw BuildPortPatchBodyError.invalidPort(key: field.key)
            }

            body[field.key] = .int(intValue)
        }

        return body
    }
}
