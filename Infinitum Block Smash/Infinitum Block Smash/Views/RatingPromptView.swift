/******************************************************
 * FILE: RatingPromptView.swift
 * MARK: App Store Rating Prompt Modal
 * CREATED: 6/19/2025 by @jrftw
 ******************************************************/

/*
 * PURPOSE:
 * Displays a modal prompt asking users to rate the app on the App Store,
 * encouraging positive reviews and feedback for the application.
 *
 * KEY RESPONSIBILITIES:
 * - Present rating prompt modal overlay
 * - Handle user interaction with rating request
 * - Integrate with StoreKit for App Store review
 * - Provide dismiss option for user choice
 * - Manage modal presentation state
 *
 * MAJOR DEPENDENCIES:
 * - SwiftUI: Core UI framework for view rendering
 * - StoreKit: App Store review integration
 * - UIKit: Scene management for review request
 *
 * EXTERNAL FRAMEWORKS USED:
 * - SwiftUI: Main UI framework for view structure and modal presentation
 * - StoreKit: Native App Store review functionality
 * - UIKit: Scene management for review controller integration
 *
 * ARCHITECTURE ROLE:
 * Modal presentation layer that encourages user engagement
 * through App Store ratings and reviews.
 *
 * CRITICAL ORDER / EXECUTION NOTES:
 * - Modal state is controlled by parent view through binding
 * - StoreKit review request requires active UIWindowScene
 * - User can dismiss without rating to avoid negative experiences
 */

/******************************************************
 * REVIEW NOTES:
 * - StoreKit review request has system-imposed limits
 * - Modal dismissal provides user choice and control
 * - Review timing should be strategic to maximize positive ratings
 *
 * FUTURE IDEAS / SUGGESTIONS:
 * - Add analytics tracking for rating prompt interactions
 * - Implement smart timing for rating prompts
 * - Add feedback collection before rating request
 * - Track rating prompt effectiveness metrics
 ******************************************************/

import SwiftUI
import StoreKit

struct RatingPromptView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                
                Text("Enjoying the Game?")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("If you're having fun, please take a moment to rate Infinitum Block Smash. Your feedback helps us improve!")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Maybe Later")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: scene)
                        }
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Rate Now")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
} 