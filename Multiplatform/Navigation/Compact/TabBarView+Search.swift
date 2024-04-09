//
//  SearchTab.swift
//  Music
//
//  Created by Rasmus Krämer on 06.09.23.
//

import SwiftUI

extension TabBarView {
    struct SearchTab: View {
        var body: some View {
            SearchView()
                .modifier(CompactNowPlayingBarModifier())
                .modifier(AccountToolbarButtonModifier())
                .tabItem {
                    Label("tab.search", systemImage: "magnifyingglass")
                }
        }
    }
}
