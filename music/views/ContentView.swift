//
//  ContentView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

struct ContentView: View {
    @State private var tracks: [String] = []

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    initFs()
                    tracks = listTracks()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            List(tracks, id: \.self) { track in
                Text(track)
            }
        }
        .padding()
        .onAppear {
            tracks = listTracks()
        }
    }
}
