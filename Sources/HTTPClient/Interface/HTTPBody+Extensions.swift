import Foundation

extension HTTPBody {
    /// Decodes the HTTP body as the specified type using the provided decoder.
    /// - Parameters:
    ///   - type: The type to decode the HTTP body as.
    ///   - decoder: The decoder to use for decoding the HTTP body.
    /// - Returns: The decoded value.
    /// - Throws: An error if the HTTP body cannot be decoded.
    public func decode<T: Decodable>(
        as type: T.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await Data(collecting: self, upTo: .max)
        return try decoder.decode(type, from: data)
    }

    /// Decodes the HTTP body as a JSON object.
    /// - Returns: The decoded JSON object.
    /// - Throws: An error if the HTTP body cannot be decoded as JSON.
    public func json() async throws -> Any {
        let data = try await Data(collecting: self, upTo: .max)
        return try JSONSerialization.jsonObject(with: data)
    }

    /// Decodes the HTTP body as a string.
    /// - Returns: The decoded string.
    /// - Throws: An error if the HTTP body cannot be decoded as a string.
    public func string() async throws -> String {
        try await String(collecting: self, upTo: .max)
    }
}
