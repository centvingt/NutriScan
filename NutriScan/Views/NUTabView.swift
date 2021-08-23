//
//  NUTabView.swift
//  NutriScan
//
//  Created by Vincent Caronnet on 22/08/2021.
//

import SwiftUI
import Combine

struct NUTabView: View {
    @Namespace private var scanNamespace
    
    @State private var goToResult = false
    @State private var eanCode = "3229820108605"
    @State private var showDetail = false

    @StateObject var cardDetailManager = CardDetailManager()
        
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("Menu", systemImage: "list.dash")
                }
        }
        .overlay(
            Group {
                if let cardDetailView = cardDetailManager.cardDetailView {
                    cardDetailView
                }
            }
            .padding(.top)
            .ignoresSafeArea()
        )
        .environmentObject(cardDetailManager)
    }
}

struct NUTabView_Previews: PreviewProvider {
    static var previews: some View {
        NUTabView()
    }
}

class CardDetailManager: ObservableObject {
    @Published var cardDetailView: CardDetailView?
    
    func setCardDetailView(
        namespace: Namespace.ID,
        cardType: CardView.CardType
    ) {
        self.cardDetailView = CardDetailView(
            namespace: namespace,
            cardType: cardType
        )
    }
}
