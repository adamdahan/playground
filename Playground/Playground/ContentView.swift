//
//  ContentView.swift
//  Playground
//
//  Created by Adam Dahan on 2024-08-28.
//

import SwiftUI

struct ContentView: View {
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            // Main content background
            Color.white
                .ignoresSafeArea()
            
            VStack {
                Button("Show Alert") {
                    withAnimation {
                        showAlert = true
                    }
                }
                .padding()
            }
            
            // Custom alert
            CustomAlertView(isPresented: $showAlert)
                .onTapGesture {
                    showAlert = false
                }
        }
    }
}

struct CustomAlertView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background fade-in/out with slower animation
            if isPresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: isPresented)
            }
            
            // Foreground slide-in/out with bouncy animation
            VStack {
                Spacer()
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 300, height: 200)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .offset(y: isPresented ? -(UIScreen.main.bounds.height / 4) : UIScreen.main.bounds.height / 2 + 100)
                    .animation(Animation.interpolatingSpring(stiffness: 70, damping: 9)
                                .speed(0.8), value: isPresented)
                
                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


struct FullscreenModifier: ViewModifier {
    var backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .background(backgroundColor)
            .edgesIgnoringSafeArea(.all)
    }
}

extension View {
    func fullscreen(backgroundColor: Color = .white) -> some View {
        self.modifier(FullscreenModifier(backgroundColor: backgroundColor))
    }
}

