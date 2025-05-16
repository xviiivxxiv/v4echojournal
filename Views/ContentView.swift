//
//  ContentView.swift
//  V3 Echojournal
//
//  Created by Papi on 21/04/2025.
//

import SwiftUI
import CoreData
import LocalAuthentication // Import for LAError

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntryCD.createdAt, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<JournalEntryCD>

    // Enum to track the flow within onboarding
    enum OnboardingStep {
        case welcome
        case intention
        case tone
    }

    @AppStorage("isOnboardingComplete") private var isOnboardingComplete: Bool = false
    @AppStorage("isFaceIDEnabled") private var isFaceIDEnabled: Bool = false // Get Face ID setting
    
    @State private var currentOnboardingStep: OnboardingStep = .welcome
    @State private var selectedIntention: String? = nil
    @State private var selectedTone: String? = nil
    
    // Authentication State
    @State private var isAuthenticated: Bool = false
    @State private var authCheckComplete: Bool = false
    @State private var authError: String? = nil

    var body: some View {
        Group {
            if !authCheckComplete {
                // Show loading indicator while checking/performing auth
                ProgressView()
                    .tint(Color.secondaryTaupe)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.backgroundCream.ignoresSafeArea())
            } else if !isAuthenticated {
                // Show locked view if auth failed or was cancelled
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondaryTaupe)
                    Text("Authentication Required")
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .foregroundColor(.primaryEspresso)
                    if let authError = authError {
                        Text(authError)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Button("Try Again") {
                        attemptAuthentication()
                    }
                    .buttonStyle(PillButtonStyle())
                    .padding(.horizontal, 50)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundCream.ignoresSafeArea())
            } else {
                // Proceed to Onboarding or Home if authenticated
                if isOnboardingComplete {
                    // Wrap HomeView in NavigationStack to enable its NavigationLinks
                    NavigationStack {
                        HomeView()
                    }
                } else {
                    // Onboarding Flow (remains outside NavigationStack initially)
                    switch currentOnboardingStep {
                    case .welcome:
                        WelcomeView(onGetStarted: {
                            withAnimation {
                                currentOnboardingStep = .intention
                            }
                        })
                    case .intention:
                        OnboardingIntentionView(
                            onIntentionSelected: { intention in
                                print("Intention: \(intention)")
                                selectedIntention = intention // Store selection
                                withAnimation {
                                    currentOnboardingStep = .tone
                                }
                            },
                            onSkip: { completeOnboarding() }
                        )
                    case .tone:
                        OnboardingToneView(
                            onToneSelected: { tone in
                                print("Tone: \(tone)")
                                selectedTone = tone // Store selection
                                completeOnboarding()
                            },
                            onSkip: { completeOnboarding() }
                        )
                    }
                }
            }
        }
        .onAppear {
             attemptAuthentication()
        }
        // Apply the background color globally for the onboarding flow if needed
        // or ensure each onboarding view sets its own background.
    }

    private func addItem() {
        withAnimation {
            let newItem = JournalEntryCD(context: viewContext)
            newItem.createdAt = Date()

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // Mark onboarding as complete and transition to main app
    private func completeOnboarding() {
        // TODO: Persist selectedIntention and selectedTone if needed (e.g., UserDefaults, CoreData, ViewModel)
        print("Onboarding Complete. Intention: \(selectedIntention ?? "N/A"), Tone: \(selectedTone ?? "N/A")")
        withAnimation {
            isOnboardingComplete = true
        }
    }

    // Helper function to run the authentication check
    private func attemptAuthentication() {
        authError = nil // Clear previous error
        
        // If Face ID setting is disabled, consider user authenticated immediately
        guard isFaceIDEnabled else {
            print("Auth: Face ID not enabled, skipping check.")
            isAuthenticated = true
            authCheckComplete = true
            return
        }
        
        // If Face ID is enabled, attempt biometric auth
        print("Auth: Face ID enabled, attempting biometrics...")
        authCheckComplete = false // Reset check status for retry
        AuthenticationService.shared.authenticateWithBiometrics { success, error in
            isAuthenticated = success
            if !success {
                 // Use the error's localized description by default
                 authError = error?.localizedDescription ?? "Authentication failed."
                 
                 // Check specific LAError codes for more user-friendly messages
                 if let errorCode = error?.code { // Safely unwrap the error code
                      switch errorCode {
                      case .userCancel:
                           authError = "Authentication cancelled."
                      case .appCancel:
                           authError = "Authentication cancelled by app."
                      case .passcodeNotSet:
                          authError = "No passcode set. Please set a passcode to use Face ID/Touch ID."
                          // TODO: Optionally disable the toggle here?
                          // isFaceIDEnabled = false 
                      case .biometryNotAvailable:
                          authError = "Face ID/Touch ID is not available on this device."
                          // TODO: Optionally disable the toggle here?
                          // isFaceIDEnabled = false
                      case .biometryLockout:
                          authError = "Too many failed attempts. Face ID/Touch ID is locked."
                      case .authenticationFailed:
                          // Keep the default localizedDescription for generic failures
                          authError = error?.localizedDescription ?? "Authentication failed."
                      // Add other cases as needed
                      default:
                          // Use the default localizedDescription if code is not specifically handled
                          authError = error?.localizedDescription ?? "Authentication failed."
                      }
                 } 
            }
            authCheckComplete = true
            print("Auth: Check complete. Success: \(success)")
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    // Provide a preview, perhaps resetting onboarding state for testing
    ContentView()
        .onAppear {
            // Uncomment to reset onboarding for preview
            // UserDefaults.standard.removeObject(forKey: "isOnboardingComplete")
        }
}
