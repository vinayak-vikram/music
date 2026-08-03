//
//  MetadataEditView.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import SwiftUI


struct MetadataEditView: View {
    let track: String

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var trackNumber = ""
    @State private var year = ""
    @State private var genre = ""
    @State private var composer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Metadata")
                .font(.headline)

            Form {
                TextField("Title", text: $title)
                TextField("Artist", text: $artist)
                TextField("Album", text: $album)
                TextField("Track Number", text: $trackNumber)
                TextField("Year", text: $year)
                TextField("Genre", text: $genre)
                TextField("Composer", text: $composer)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    saveMetadata(
                        TrackMetadata(
                            title: title.isEmpty ? nil : title,
                            artist: artist.isEmpty ? nil : artist,
                            album: album.isEmpty ? nil : album,
                            trackNumber: Int(trackNumber),
                            year: Int(year),
                            genre: genre.isEmpty ? nil : genre,
                            composer: composer.isEmpty ? nil : composer
                        ),
                        for: track
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            let metadata = verifyIndex(for: track)
            title = metadata.title ?? ""
            artist = metadata.artist ?? ""
            album = metadata.album ?? ""
            trackNumber = metadata.trackNumber.map(String.init) ?? ""
            year = metadata.year.map(String.init) ?? ""
            genre = metadata.genre ?? ""
            composer = metadata.composer ?? ""
        }
    }
}
