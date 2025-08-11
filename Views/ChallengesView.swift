import SwiftUI

struct ChallengesView: View {
    // Connect to the main HomeView's state, which is now the single source of truth
    @ObservedObject var homeViewModel: HomeViewModel
    @Binding var mainSelectedTab: HomeView.Tab
    
    // State to manage which challenge detail to show in the modal
    @Binding var selectedChallengeForModal: Challenge?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Challenges")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.buttonBrown)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 15)
                    .padding(.bottom, 10)

                // Section for Active Challenges
                if !homeViewModel.activeChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(homeViewModel.activeChallenges) { attempt in
                            if let challenge = homeViewModel.getChallenge(from: attempt) {
                                ActiveChallengeCardView(
                                    challenge: challenge,
                                    attempt: attempt,
                                    homeViewModel: homeViewModel,
                                    mainSelectedTab: $mainSelectedTab
                                )
                            }
                        }
                    }
                }
                
                // Section for Available Challenges
                // Re-calculate available challenges directly here based on the single source of truth
                let availableChallenges = ChallengeData.samples.filter { challenge in
                    !homeViewModel.activeChallenges.contains { $0.challengeID == challenge.id.uuidString }
                }
                
                if !availableChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(availableChallenges) { challenge in
                            ChallengeCardView(challenge: challenge)
                                .onTapGesture {
                                    withAnimation {
                                        selectedChallengeForModal = challenge
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .background(Color.backgroundCream.ignoresSafeArea())
        .onAppear {
            homeViewModel.fetchActiveChallenges()
        }
    }
}

// MARK: - Active Challenge Card
struct ActiveChallengeCardView: View {
    let challenge: Challenge
    let attempt: ChallengeAttempt
    
    // Connect to the main HomeView's state
    @ObservedObject var homeViewModel: HomeViewModel
    @Binding var mainSelectedTab: HomeView.Tab

    // Calculate progress
    private var progress: Double {
        let completed = Double(attempt.completedDays?.split(separator: ",").count ?? 0)
        let total = Double(challenge.durationInDays)
        return total > 0 ? completed / total : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: challenge.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                Spacer()
                // Potentially add a settings/more button here
            }
            
            Text(challenge.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            ProgressView(value: progress)
                .tint(.white)
            
            Text("\(attempt.completedDays?.split(separator: ",").count ?? 0)/\(challenge.durationInDays) days entered")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Button {
                // When tapped, set the requested mode and switch tabs
                let completedCount = attempt.completedDays?.split(separator: ",").count ?? 0
                let dayIndex = min(completedCount, challenge.durationInDays - 1)
                homeViewModel.requestedMode = .challenge(attempt: attempt, dayIndex: dayIndex)
                mainSelectedTab = .entry
            } label: {
                Text("+ Log Today's Entry")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(challenge.gradient)
        .cornerRadius(20)
        .shadow(color: challenge.themeColor.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Challenge Card View
struct ChallengeCardView: View {
    let challenge: Challenge

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: challenge.iconName)
                .font(.system(size: 40))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            Text(challenge.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(challenge.subtitle)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Text("View Challenge")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(challenge.themeColor)
                .padding(.vertical, 16)
                .padding(.horizontal, 40)
                .background(Color.white)
                .cornerRadius(30)
            
            HStack {
                Image(systemName: "person.2.fill")
                Text("\(challenge.participantCount) participating")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(challenge.gradient)
        .cornerRadius(20)
        .shadow(color: challenge.themeColor.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Challenge Detail View (for Modal Sheet)
struct ChallengeDetailView: View {
    let challenge: Challenge
    @ObservedObject var viewModel: HomeViewModel
    @Binding var mainSelectedTab: HomeView.Tab
    let dismissAction: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Spacer()
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }

            Image(systemName: challenge.iconName)
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.white)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(challenge.themeColor.gradient)
                )
            
            Text(challenge.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 20) {
                metadataItem(icon: "clock.fill", text: "\(challenge.durationInDays) days")
                metadataItem(icon: "person.2.fill", text: "\(challenge.participantCount) participants")
                metadataItem(icon: "chart.bar.fill", text: challenge.difficulty)
            }
            .foregroundColor(.white)
            .font(.system(size: 14))
            .padding(.top, 5)

            VStack(alignment: .leading, spacing: 10) {
                Text("What to expect:")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                ForEach(challenge.whatToExpect, id: \.self) { item in
                    HStack {
                        let isSpecialItem = item.contains("personalized report")
                        Image(systemName: isSpecialItem ? "star.fill" : "checkmark")
                            .foregroundColor(isSpecialItem ? .accentColor : .green)
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.2))
            .cornerRadius(12)
            .padding(.top, 10)

            Text("Whether you're new or returning to journaling, this challenge helps you")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Button("Start Challenge") {
                viewModel.startChallenge(challenge: challenge)
                mainSelectedTab = .entry
                dismissAction()
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(challenge.themeColor)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(20)
        }
    }

    private func metadataItem(icon: String, text: String) -> some View {
        VStack {
            Image(systemName: icon)
            Text(text)
        }
    }
}

// MARK: - Preview
#Preview {
    // This preview will need a managedObjectContext to work correctly now
    ChallengesView(
        homeViewModel: HomeViewModel(transcriptionService: WhisperTranscriptionService.shared),
        mainSelectedTab: .constant(.entry),
        selectedChallengeForModal: .constant(nil)
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 