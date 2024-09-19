//
//  CustomSheet.swift
//  DynamicSheet
//
//  Created by Adam Dahan on 2024-09-19.
//

import SwiftUI

struct CustomSheetView<Content: View>: View {
    
    private var gap: CGFloat = 56
    
    @Binding var isPresented: Bool
    @State private var contentHeight: CGFloat = 0 // Dynamic height of the content
    let maxHeight: CGFloat // Maximum height for the sheet
    let content: Content

    init(isPresented: Binding<Bool>, maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.maxHeight = maxHeight
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Background overlay with a fade effect
            if isPresented {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isPresented = false
                        }
                    }
            }
            
            // The sheet content with slide animation
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    
                    // Content with dynamic height calculation
                    content
                        .background(GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    contentHeight = min(geometry.size.height, maxHeight) // Limit content height
                                }
                                .onChange(of: geometry.size.height) { newHeight in
                                    contentHeight = min(newHeight, maxHeight)
                                }
                        })
                    
//                    // Dismiss button (optional, can customize)
//                    Button(action: {
//                        withAnimation(.easeInOut) {
//                            isPresented = false
//                        }
//                    }) {
//                        Text("Dismiss")
//                            .font(.headline)
//                            .foregroundColor(.blue)
//                    }
//                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: contentHeight) // Dynamic height
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                .offset(y: isPresented ? gap : contentHeight + gap) // Slide in and out
                .animation(.easeInOut(duration: 0.3), value: isPresented)
            }
        }
        .animation(.easeInOut, value: isPresented)
    }
}
