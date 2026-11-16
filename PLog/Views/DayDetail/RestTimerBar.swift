//
//  RestTimerBar.swift
//  PLog
//
//  The rest timer on the session screen: a small capsule above the tab bar. Idle, it's one
//  button — tap to start, touch and hold to choose the length. Running, it shows the time
//  left with +30 s and stop beside it. It reads the app's one `RestTimer`, so a countdown
//  started here carries on if the user looks at another tab.
//

import SwiftUI

struct RestTimerBar: View {
    @State private var timer = RestTimer.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if timer.isRunning {
                running
            } else {
                idle
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 6)
        .frame(minHeight: 44)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator.opacity(0.6)))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.bottom, 8)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: timer.isRunning)
        .sensoryFeedback(.impact(weight: .light), trigger: timer.isRunning)
    }

    // MARK: - Idle

    private var idle: some View {
        Menu {
            Picker("Rest Length", selection: $timer.duration) {
                ForEach(RestTimer.presets, id: \.self) { seconds in
                    Text(RestTimer.spoken(seconds)).tag(seconds)
                }
            }
        } label: {
            Label("Rest \(RestTimer.clock(TimeInterval(timer.duration)))", systemImage: "timer")
                .monospacedDigit()
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        } primaryAction: {
            timer.start()
        }
        .tint(.primary)
        .accessibilityLabel("Start rest timer, \(RestTimer.spoken(timer.duration))")
        .accessibilityHint("Touch and hold to change the length")
    }

    // MARK: - Running

    private var running: some View {
        HStack(spacing: 4) {
            // The countdown only needs a tick a second; nothing else on the screen redraws.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 8) {
                    ProgressView(value: timer.progress(at: context.date))
                        .progressViewStyle(.linear)
                        .frame(width: 44)
                        .accessibilityHidden(true)
                    Text(RestTimer.clock(timer.remaining(at: context.date)))
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                        .frame(minWidth: 40, alignment: .leading)
                }
                .padding(.leading, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest")
                .accessibilityValue("\(Int(timer.remaining(at: context.date).rounded(.up))) seconds left")
            }

            Button {
                timer.add(30)
            } label: {
                Text("+30s")
                    .padding(.horizontal, 8)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add 30 seconds")

            Button {
                timer.stop()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Stop rest timer")
        }
        .buttonStyle(.borderless)
        .tint(.primary)
    }
}

#Preview {
    Color(uiColor: .systemGroupedBackground)
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom) { RestTimerBar() }
}
