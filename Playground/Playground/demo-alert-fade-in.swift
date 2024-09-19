//
//  demo-alert-fade-in.swift
//  Playground
//
//  Created by Adam Dahan on 2024-08-30.
//

import SwiftUI

//struct CustomAlertView: View {
//    @Binding var isPresented: Bool
//    
//    var body: some View {
//        ZStack {
//            // Black background
//            if isPresented {
//                Color.black.opacity(0.5)
//                    .ignoresSafeArea()
//                    .transition(.opacity)
//            }
//            
//            // Alert box
//            if isPresented {
//                VStack {
//                    Spacer()
//                    
//                    Rectangle()
//                        .fill(Color.white)
//                        .frame(width: 300, height: 200)
//                        .cornerRadius(12)
//                        .shadow(radius: 10)
//                        .transition(.move(edge: .bottom))
//                    
//                    Spacer().frame(height: 20)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//            }
//        }
//        .animation(.easeInOut(duration: 0.3), value: isPresented)
//    }
//}
