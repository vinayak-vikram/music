//
//  PlayerView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var trackStore: TrackStore

    var body: some View {
        VStack {
            Button {
                trackStore.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .alignmentGuide(HorizontalAlignment.trailing) { _ in -3 }
        }
    }
}

#Preview {
    PlayerView()
        .environmentObject(TrackStore())
}
