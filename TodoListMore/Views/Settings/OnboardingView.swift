//
//  OnboardingView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 21/04/25.
//

import SwiftUI

/// A model to represent an onboarding page
struct OnboardingPage: Identifiable, Equatable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
    
    static func == (lhs: OnboardingPage, rhs: OnboardingPage) -> Bool {
        lhs.id == rhs.id
    }
}

/// View that displays the onboarding experience
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // For controlling the main app's tab selection
    @Binding var tabSelection: Int
    
    @State private var currentPage = 0
    
    // Define the onboarding pages
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "checklist.checked",
            title: "Track Your Tasks",
            description: "Easily create, organize, and track your daily tasks with a beautiful, intuitive interface."
        ),
        OnboardingPage(
            image: "folder.fill",
            title: "Categorize",
            description: "Group related tasks into categories with custom colors and icons for better organization."
        ),
        OnboardingPage(
            image: "calendar",
            title: "Due Dates & Reminders",
            description: "Set due dates and receive reminders so you never miss an important task."
        ),
        OnboardingPage(
            image: "arrow.clockwise",
            title: "Recurring Tasks",
            description: "Create tasks that repeat daily, weekly, or monthly to maintain your routine."
        ),
        OnboardingPage(
            image: "widgetimage", // Custom image name
            title: "Home Screen Widgets",
            description: "View your tasks directly from your home screen with our custom widgets."
        )
    ]
    
    // Constructor for preview
    init() {
        self._tabSelection = .constant(0)
    }
    
    // Constructor with tab selection binding
    init(tabSelection: Binding<Int>) {
        self._tabSelection = tabSelection
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#5D4EFF").opacity(0.8),
                    Color(hex: "#5D4EFF")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Skip button for fast exit
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                
                // App logo/icon
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Navigation buttons
                HStack {
                    // Back button
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        }
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Next/Get Started button
                    Button(action: {
                        withAnimation {
                            if currentPage < pages.count - 1 {
                                currentPage += 1
                            } else {
                                completeOnboarding()
                            }
                        }
                    }) {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(Color(hex: "#5D4EFF"))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .accessibilityIdentifier("OnboardingView")
    }
    
    private func completeOnboarding() {
        // Mark onboarding as completed
        hasCompletedOnboarding = true
        
        // Post a notification that onboarding was completed
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        
        // Reset tab selection to Tasks tab
        tabSelection = 0
        
        // Track onboarding completion
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.amplitude.track(eventType: "onboarding_completed")
        }
        
        dismiss()
    }
}

/// A single onboarding page view
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            // Feature icon - check if it's a system image or custom image
            Group {
                if UIImage(named: page.image) != nil {
                    // Custom image from assets
                    Image(page.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding(.bottom, 10)
                } else {
                    // System SF Symbol
                    Image(systemName: page.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .accessibilityLabel("Illustration for \(page.title)")
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
            
            // Spacer to push content to top half
            Spacer()
        }
        .padding(.top, 20)
    }
}

#Preview {
    OnboardingView()
}