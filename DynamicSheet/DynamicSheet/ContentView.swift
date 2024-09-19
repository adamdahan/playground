//
//  ContentView.swift
//  DynamicSheet
//
//  Created by Adam Dahan on 2024-09-19.
//

import SwiftUI

struct Card: Identifiable {
    let id = UUID()
}

// Example usage
struct ContentView: View {
    
    private enum Constants {
        static let vStackSpacing: CGFloat = 10.0
        static let rowHeight: CGFloat = 84.0
        static let headerHeight: CGFloat = 40
        static let footerHeight: CGFloat = 200
    }
    
    @State private var cards = [
        Card(),
    ]
    @State private var maxCount = 3
    @State private var showSheet = false

    var body: some View {
        ZStack {
            Button("Show Custom Sheet") {
                withAnimation {
                    showSheet = true
                }
            }

            CustomSheetView(isPresented: $showSheet, maxHeight: Constants.rowHeight * CGFloat(maxCount) + (Constants.headerHeight + Constants.footerHeight)) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: Constants.headerHeight)
                        .onTapGesture {
                            cards.append(Card())
                        }
               
                    if cards.count <= maxCount {
                        cardList
                    } else {
                        ScrollView {
                            cardList
                        }
                        .frame(height: cards.count < maxCount ? dynamicHeightForScrollView() : (Constants.rowHeight * CGFloat(maxCount)))
                    }
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: Constants.footerHeight)
                        .onTapGesture {
                            if cards.count > 0 {
                                cards.removeLast()
                            }
                        }
                    
                }
            }
        }
    }
    
    var cardList: some View {
        VStack(spacing: 0) {
            ForEach(cards) { card in
                Rectangle().fill(Color.white)
                    .frame(height: Constants.rowHeight)
                Divider()
            }
        }
    }
    
    // Dynamically calculates the height of the ScrollView based on the number of cards and spacing
    private func dynamicHeightForScrollView() -> CGFloat {
        let cardCount = min(cards.count, maxCount) // Limit the card count to maxCount
        let totalCardHeight = CGFloat(cardCount) * Constants.rowHeight
        let totalSpacing = CGFloat(cardCount - 1) * Constants.vStackSpacing // Spacing between the cards
        return totalCardHeight + totalSpacing
    }
    
    private func dynamicMaxHeight() -> CGFloat {
        let cardCount = min(cards.count, maxCount) // Limit the card count to maxCount
        let totalCardHeight = CGFloat(cardCount) * Constants.rowHeight
        let totalSpacing = CGFloat(cardCount - 1) * Constants.vStackSpacing // Spacing between the cards
        // Total height = header + cards + spacing + footer
        return Constants.headerHeight + totalCardHeight + totalSpacing + Constants.footerHeight
    }
}




#Preview {
    ContentView()
}
