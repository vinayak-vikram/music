//
//  PlayerView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

struct PlayerView: View {
    var body: some View {
        VStack {
            Button {
                initFs()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .alignmentGuide(HorizontalAlignment.trailing) { _ in -3 }
        }
    }
}

#Preview {
    PlayerView()
}
