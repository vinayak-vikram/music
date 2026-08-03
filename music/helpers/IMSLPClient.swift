//
//  IMSLPClient.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Combine
import CryptoKit
import Foundation

enum IMSLPError: Error, LocalizedError {
    case noCredentials
    case loginFailed(String)
    case invalidURL
    case naxosResolutionFailed
    case httpError(Int, String)
    case unexpectedResponse(String)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No IMSLP credentials saved."
        case .loginFailed(let reason): return "IMSLP login failed: \(reason)"
        case .invalidURL: return "Could not build a download URL."
        case .naxosResolutionFailed: return "Could not resolve the Naxos recording URL."
        case .httpError(let status, let snippet): return "IMSLP returned HTTP \(status): \(snippet)"
        case .unexpectedResponse(let snippet): return "Unexpected response from IMSLP: \(snippet)"
        }
    }
}

private func validated(_ data: Data, _ response: URLResponse) throws -> Data {
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        throw IMSLPError.httpError(http.statusCode, String(data: data.prefix(300), encoding: .utf8) ?? "")
    }
    return data
}

private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
        return try JSONDecoder().decode(type, from: data)
    } catch {
        let snippet = String(data: data.prefix(300), encoding: .utf8) ?? error.localizedDescription
        throw IMSLPError.unexpectedResponse(snippet)
    }
}

private func authFileURL() -> URL? {
    dataDirectoryURL()?.appendingPathComponent("auth.json")
}

func loadIMSLPCredentials() -> IMSLPCredentials? {
    guard let url = authFileURL(), let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode([String: IMSLPCredentials].self, from: data)["imslp"]
}

@discardableResult
func saveIMSLPCredentials(_ credentials: IMSLPCredentials) -> Bool {
    guard let url = authFileURL(),
          let data = try? JSONEncoder().encode(["imslp": credentials])
    else { return false }
    return (try? data.write(to: url, options: .atomic)) != nil
}

@MainActor
final class IMSLPClient: ObservableObject {
    static let shared = IMSLPClient()

    @Published private(set) var isLoggedIn = false

    private let base = URL(string: "https://imslp.org")!

    func login() async throws {
        guard let credentials = loadIMSLPCredentials() else { throw IMSLPError.noCredentials }
        let token = try await requestLoginToken(credentials: credentials)
        let succeeded = try await submitLogin(credentials: credentials, token: token)
        guard succeeded else { throw IMSLPError.loginFailed("Check your IMSLP username and password.") }
        isLoggedIn = true
    }

    func searchComposers(matching query: String) async throws -> [IMSLPComposer] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let url = apiURL([
            URLQueryItem(name: "action", value: "opensearch"),
            URLQueryItem(name: "search", value: "Category:" + query),
            URLQueryItem(name: "namespace", value: "14"),
            URLQueryItem(name: "limit", value: "15"),
            URLQueryItem(name: "format", value: "json"),
        ])
        let (rawData, response) = try await URLSession.shared.data(from: url)
        let data = try validated(rawData, response)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [Any],
              array.count > 1, let titles = array[1] as? [String]
        else { return [] }
        return titles.map { IMSLPComposer(categoryTitle: $0) }
    }

    func fetchWorkTitles(for composer: IMSLPComposer) async throws -> [String] {
        let url = apiURL([
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "categorymembers"),
            URLQueryItem(name: "cmtitle", value: "Category:" + composer.displayName),
            URLQueryItem(name: "cmnamespace", value: "0"),
            URLQueryItem(name: "cmlimit", value: "200"),
            URLQueryItem(name: "format", value: "json"),
        ])
        let (rawData, response) = try await URLSession.shared.data(from: url)
        let decoded = try decode(CategoryMembersResponse.self, from: try validated(rawData, response))
        return decoded.query.categorymembers
            .map(\.title)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func fetchWork(title: String, composer: String) async throws -> IMSLPWork {
        let wikitext = try await fetchWikitext(page: title)
        var work = parseWorkInfo(from: wikitext, fallbackTitle: title, composer: composer)
        var recordings = parseCommunityRecordings(from: wikitext)

        if let html = try? await fetchFullPageHTML(page: title) {
            recordings = recordings.map { recording in
                var recording = recording
                recording.duration = communityRecordingDuration(fileName: recording.fileName, in: html)
                return recording
            }
            if isLoggedIn {
                recordings += parseNaxosRecordings(from: html)
            }
        }

        work.recordings = recordings
        return work
    }

    func downloadRecording(_ recording: IMSLPRecording) async throws -> URL {
        let sourceURL: URL
        if let token = recording.naxosToken {
            sourceURL = try await resolveNaxosURL(token: token)
        } else if let url = directURL(forFileName: recording.fileName) {
            sourceURL = url
        } else {
            throw IMSLPError.invalidURL
        }
        let (tempURL, _) = try await URLSession.shared.download(from: sourceURL)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "mp3" : sourceURL.pathExtension)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private struct LoginResponse: Decodable {
        struct Login: Decodable {
            var result: String
            var token: String?
        }
        var login: Login
    }

    private func requestLoginToken(credentials: IMSLPCredentials) async throws -> String {
        let data = try await postForm(
            path: "api.php",
            query: [URLQueryItem(name: "format", value: "json")],
            body: ["action": "login", "lgname": credentials.username, "lgpassword": credentials.password]
        )
        let decoded = try decode(LoginResponse.self, from: data)
        guard let token = decoded.login.token else { throw IMSLPError.loginFailed("No token returned.") }
        return token
    }

    private func submitLogin(credentials: IMSLPCredentials, token: String) async throws -> Bool {
        let data = try await postForm(
            path: "api.php",
            query: [URLQueryItem(name: "format", value: "json")],
            body: [
                "action": "login", "lgname": credentials.username,
                "lgpassword": credentials.password, "lgtoken": token,
            ]
        )
        let decoded = try decode(LoginResponse.self, from: data)
        return decoded.login.result == "Success"
    }

    private func resolveNaxosURL(token: String) async throws -> URL {
        var request = URLRequest(url: base.appendingPathComponent("wiki/Special:GR/decodeurls"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([token])
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let resolved = try? JSONDecoder().decode([String].self, from: data).first,
              let url = URL(string: resolved)
        else { throw IMSLPError.naxosResolutionFailed }
        return url
    }

    private struct CategoryMembersResponse: Decodable {
        struct Query: Decodable { var categorymembers: [Member] }
        struct Member: Decodable { var title: String }
        var query: Query
    }

    private struct ParseWikitextResponse: Decodable {
        struct Parse: Decodable {
            struct Wikitext: Decodable {
                var value: String
                enum CodingKeys: String, CodingKey { case value = "*" }
            }
            var wikitext: Wikitext
        }
        var parse: Parse
    }

    private func fetchWikitext(page: String) async throws -> String {
        let url = apiURL([
            URLQueryItem(name: "action", value: "parse"),
            URLQueryItem(name: "page", value: page),
            URLQueryItem(name: "prop", value: "wikitext"),
            URLQueryItem(name: "format", value: "json"),
        ])
        let (rawData, response) = try await URLSession.shared.data(from: url)
        let decoded = try decode(ParseWikitextResponse.self, from: try validated(rawData, response))
        return decoded.parse.wikitext.value
    }

    private func fetchFullPageHTML(page: String) async throws -> String {
        // appendingPathComponent would double-encode an already-percent-encoded
        // segment (%20 -> %2520), so build the URL string directly instead.
        guard let encodedPage = page.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://imslp.org/wiki/\(encodedPage)")
        else { throw IMSLPError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func apiURL(_ queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: base.appendingPathComponent("api.php"), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        return components.url!
    }

    private func postForm(path: String, query: [URLQueryItem], body: [String: String]) async throws -> Data {
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = body.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value)"
        }.joined(separator: "&")
        request.httpBody = encoded.data(using: .utf8)
        let (rawData, response) = try await URLSession.shared.data(for: request)
        return try validated(rawData, response)
    }

    private func directURL(forFileName fileName: String) -> URL? {
        guard let nameData = fileName.data(using: .utf8) else { return nil }
        let hex = Insecure.MD5.hash(data: nameData).map { String(format: "%02x", $0) }.joined()
        guard let firstChar = hex.first,
              let encodedName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        // appendingPathComponent would double-encode encodedName, so build the URL string directly.
        return URL(string: "https://imslp.org/images/\(firstChar)/\(hex.prefix(2))/\(encodedName)")
    }
}

private func parseWorkInfo(from wikitext: String, fallbackTitle: String, composer: String) -> IMSLPWork {
    let title = firstMatch(#"\|Work Title=([^\n]*)"#, in: wikitext)?.trimmingCharacters(in: .whitespaces)
    let year = firstMatch(#"\|Year/Date of Composition=([^\n]*)"#, in: wikitext).flatMap(leadingYear)
    return IMSLPWork(
        title: (title?.isEmpty == false) ? title! : fallbackTitle,
        composer: composer,
        year: year,
        recordings: []
    )
}

private func parseCommunityRecordings(from wikitext: String) -> [IMSLPRecording] {
    extractBlocks(prefix: "{{#fte:imslpaudio", between: "*****AUDIO*****", and: "*****FILES*****", in: wikitext)
        .flatMap { block -> [IMSLPRecording] in
            let fields = parseFields(in: block)
            let artist = performerString(from: fields)
            var recordings: [IMSLPRecording] = []
            var index = 1
            while let fileName = fields["File Name \(index)"], !fileName.isEmpty {
                let description = fields["File Description \(index)"]
                let isCompletePerformance = description?.localizedCaseInsensitiveContains("complete") ?? false
                recordings.append(
                    IMSLPRecording(
                        movement: isCompletePerformance ? nil : description,
                        artist: artist,
                        album: nil,
                        fileName: fileName,
                        naxosToken: nil
                    )
                )
                index += 1
            }
            return recordings
        }
}

private func performerString(from fields: [String: String]) -> String? {
    var parts: [String] = []
    if let performers = fields["Performers"], !performers.isEmpty {
        parts.append(stripWikiLinks(performers))
    }
    if let categories = fields["Performer Categories"], !categories.isEmpty {
        let names = categories.components(separatedBy: ";").compactMap { entry -> String? in
            let name = entry.components(separatedBy: "=").first?.trimmingCharacters(in: .whitespaces)
            return (name?.isEmpty == false) ? name : nil
        }
        parts.append(contentsOf: names)
    }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
}

// must regex out of webpage bc gee
private func communityRecordingDuration(fileName: String, in html: String) -> TimeInterval? {
    let displayName = fileName.replacingOccurrences(of: "_", with: " ")
    guard let markerRange = html.range(of: "title=\"File:\(displayName)\"") else { return nil }
    let window = html[markerRange.upperBound...].prefix(200)
    guard let match = window.range(of: #"(\d+):(\d{2})(?::(\d{2}))?"#, options: .regularExpression) else { return nil }
    let parts = window[match].split(separator: ":").compactMap { Int($0) }
    switch parts.count {
    case 2: return TimeInterval(parts[0] * 60 + parts[1])
    case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
    default: return nil
    }
}

private func stripWikiLinks(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"\[\[(?:[^|\]]*\|)?([^\]]+)\]\]"#) else { return text }
    return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1")
}

// Finds `{{#fte:imslpaudio ... }}`-style blocks between two section markers,
// tracking brace depth manually since wikitext templates nest arbitrarily
// (e.g. `Publisher Information={{RC||...}}`) and regex cannot match that
private func extractBlocks(prefix: String, between startMarker: String, and endMarker: String, in text: String) -> [String] {
    guard let sectionStart = text.range(of: startMarker), let sectionEnd = text.range(of: endMarker) else { return [] }
    let section = String(text[sectionStart.upperBound..<sectionEnd.lowerBound])

    var blocks: [String] = []
    var searchStart = section.startIndex
    while let blockStart = section.range(of: prefix, range: searchStart..<section.endIndex) {
        guard let blockEnd = matchingBraceEnd(in: section, from: blockStart.lowerBound) else { break }
        blocks.append(String(section[blockStart.lowerBound..<blockEnd]))
        searchStart = blockEnd
    }
    return blocks
}

private func matchingBraceEnd(in text: String, from start: String.Index) -> String.Index? {
    var depth = 0
    var index = start
    while index < text.endIndex {
        if text[index...].hasPrefix("{{") {
            depth += 1
            index = text.index(index, offsetBy: 2)
        } else if text[index...].hasPrefix("}}") {
            depth -= 1
            index = text.index(index, offsetBy: 2)
            if depth == 0 { return index }
        } else {
            index = text.index(after: index)
        }
    }
    return nil
}

private func parseFields(in block: String) -> [String: String] {
    var fields: [String: String] = [:]
    var currentKey: String?
    var currentValue = ""
    for line in block.components(separatedBy: "\n") {
        if let keyRange = line.range(of: #"^\|([^=]+)="#, options: .regularExpression) {
            if let key = currentKey {
                fields[key] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            currentKey = String(line[keyRange].dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            currentValue = String(line[keyRange.upperBound...])
        } else if currentKey != nil {
            currentValue += "\n" + line
        }
    }
    if let key = currentKey {
        fields[key] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return fields
}

private func firstMatch(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[range])
}

private func leadingYear(_ text: String) -> Int? {
    guard let range = text.range(of: #"\d{4}"#, options: .regularExpression) else { return nil }
    return Int(text[range])
}

private struct NaxosAlbum: Decodable {
    var tit: String
    var art: String
    var trs: [NaxosTrack]
}

private struct NaxosTrack: Decodable {
    var dsc: String
    var url: String
    var dur: Double
}

private func parseNaxosRecordings(from html: String) -> [IMSLPRecording] {
    guard let markerRange = html.range(of: "JGCommRec=["),
          let jsonString = extractBalancedJSONArray(from: html, startingAt: html.index(before: markerRange.upperBound)),
          let jsonData = jsonString.data(using: .utf8),
          let albums = try? JSONDecoder().decode([NaxosAlbum].self, from: jsonData)
    else { return [] }

    return albums.flatMap { album in
        album.trs.map { track in
            IMSLPRecording(
                movement: movementFromDescription(track.dsc),
                artist: album.art,
                album: album.tit,
                fileName: track.dsc,
                naxosToken: track.url,
                duration: track.dur
            )
        }
    }
}

private func movementFromDescription(_ description: String) -> String {
    guard let colonRange = description.range(of: ": ", options: .backwards) else { return description }
    return String(description[colonRange.upperBound...])
}

private func extractBalancedJSONArray(from text: String, startingAt openBracket: String.Index) -> String? {
    var depth = 0
    var inString = false
    var isEscaped = false
    var index = openBracket
    while index < text.endIndex {
        let char = text[index]
        if inString {
            if isEscaped {
                isEscaped = false
            } else if char == "\\" {
                isEscaped = true
            } else if char == "\"" {
                inString = false
            }
        } else if char == "\"" {
            inString = true
        } else if char == "[" {
            depth += 1
        } else if char == "]" {
            depth -= 1
            if depth == 0 {
                return String(text[openBracket...index])
            }
        }
        index = text.index(after: index)
    }
    return nil
}

func trackMetadata(for recording: IMSLPRecording, work: IMSLPWork) -> TrackMetadata {
    TrackMetadata(
        title: nil,
        artist: recording.artist,
        album: recording.album,
        trackNumber: nil,
        year: work.year,
        genre: "Classical",
        composer: work.composer,
        piece: work.title,
        movement: recording.movement
    )
}
