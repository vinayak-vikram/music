//
//  IMSLPModels.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Foundation

struct IMSLPCredentials: Codable {
    var username: String
    var password: String
}

struct IMSLPRecording: Identifiable {
    let id = UUID()
    var movement: String?
    var artist: String?
    var album: String?
    var fileName: String
    var naxosToken: String?

    var isNaxos: Bool { naxosToken != nil }
}

struct IMSLPWork: Identifiable {
    let id = UUID()
    var title: String
    var composer: String
    var year: Int?
    var recordings: [IMSLPRecording]
}

struct IMSLPComposer: Identifiable, Hashable {
    let id: String
    var displayName: String

    init(categoryTitle: String) {
        let name = categoryTitle.hasPrefix("Category:") ? String(categoryTitle.dropFirst("Category:".count)) : categoryTitle
        self.id = name
        self.displayName = name
    }
}
