//
//  ContentView.swift
//  PLog
//
//  Root tab bar: Train (today's workout + the session log), Progress (analytics, with the
//  calendar pushed from it), Plans and Exercises. Settings is a sheet behind Train's profile
//  button. Each tab owns its own NavigationStack. A brand-new install gets the welcome
//  sheet over it once.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    /// True from a fresh install's first launch until the welcome sheet is dismissed.
    @AppStorage(Onboarding.welcomePendingKey) private var welcomePending = false

    /// Observed here, at the root, so "rest over" is felt on whichever tab is showing.
    @State private var restTimer = RestTimer.shared

    var body: some View {
        TabView {
            TrainView()
                .tabItem {
                    Label("Train", systemImage: "figure.strengthtraining.traditional")
                }

            AnalyticsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            PlanListView()
                .tabItem {
                    Label("Plans", systemImage: "list.clipboard")
                }

            ExerciseLibraryView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
        }
        .sensoryFeedback(.success, trigger: restTimer.finishedCount)
        // Dismissing it any way (a choice, Skip, or a swipe) clears the flag.
        .sheet(isPresented: $welcomePending) {
            WelcomeView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.container)
}
