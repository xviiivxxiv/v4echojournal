import SwiftUI

struct JournalingPageView: View {
    @ObservedObject var viewModel: HomeViewModel
    let mode: JournalEntryMode
    
    // Bindings are no longer needed here
    
    var body: some View {
        VStack(spacing: 0) {
            // The JournalModeSelectorView has been removed from here.
            
            Spacer(minLength: 0)

            // Dynamic content based on the selected mode
            Group {
                switch mode {
                case .standard:
                    Text("How is your day?")
                        .fontWeight(.regular)
                        .foregroundColor(mode.themeColor)
                case .challenge(let attempt, let dayIndex):
                    if let challenge = viewModel.getChallenge(from: attempt) {
                        VStack(spacing: 20) {
                            Text(challenge.dailyPrompts[safe: dayIndex] ?? "Challenge prompt not found.")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(mode.themeColor)
                            
                            ChallengeDaySelectorView(
                                duration: challenge.durationInDays,
                                completedDays: attempt.completedDaysSet,
                                selectedDayIndex: dayIndex
                            )
                        }
                    } else {
                        Text("Could not load challenge details.")
                    }
                }
            }
            .font(.system(size: 28, weight: .bold, design: .default))
            .multilineTextAlignment(.center)
            .padding(.bottom, 32)
            
            Spacer(minLength: 0)

            Text(viewModel.isRecording ? "Recording... Tap to stop" : "Tap the mic to start journaling")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(Color.secondaryTaupe)
                .multilineTextAlignment(.center)
                .padding(.bottom, 15)

            HStack(alignment: .center, spacing: 32) {
                Button {
                    print("Type button tapped")
                } label: {
                    VStack {
                        Image(systemName: "pencil.and.outline")
                            .font(.system(size: 28, design: .default))
                        Text("Type")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.buttonBrown)
                }
                .frame(width: 60)

                Button {
                    viewModel.toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(mode.themeColor)
                            .frame(width: 80, height: 80)
                        Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    print("Prompts button tapped")
                } label: {
                    VStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, design: .default))
                        Text("Prompts")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(Color.buttonBrown)
                }
                .frame(width: 60)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 20)
    }
} 