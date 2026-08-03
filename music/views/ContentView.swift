//
//  ContentView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var trackStore: TrackStore

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    trackStore.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            List(trackStore.tracks, id: \.self) { track in
                Text(track)
            }
        }
        .padding()
        .onAppear {
            trackStore.refresh()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TrackStore())
}
