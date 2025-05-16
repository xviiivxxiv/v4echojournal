import SwiftUI
import CoreData

// Simple struct to represent a message in the chat
// MOVED to Models/ChatMessage.swift
/*
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}
*/

struct ConversationView: View {
    @ObservedObject private var viewModel: ConversationViewModel
    @StateObject private var followUpLoopController: FollowUpLoopController
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // State uses the updated ChatMessage model
    @State private var chatMessages: [ChatMessage] = []
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    @State private var showSessionEndView = false

    init(journalEntry: JournalEntryCD) {
        let initialViewModel = ConversationViewModel(
            journalEntry: journalEntry,
            context: PersistenceController.shared.container.viewContext
        )
        _viewModel = ObservedObject(wrappedValue: initialViewModel)

        _followUpLoopController = StateObject(wrappedValue: FollowUpLoopController(
            context: PersistenceController.shared.container.viewContext,
            gptService: GPTService.shared,
            transcriptionService: WhisperTranscriptionService.shared,
            audioRecorder: AudioRecorder.shared
        ))
        
        // Initialize chatMessages directly here if needed, or in onAppear
        // _chatMessages = State(initialValue: [
        //     ChatMessage(text: journalEntry.entryText ?? "No transcript", isUser: true)
        // ])
    }

    var body: some View {
        ZStack {
            Color.backgroundCream.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                
                // --- Latency Banner --- 
                if followUpLoopController.isExperiencingHighLatency {
                    Text("⚡️ Slower transcription due to network.")
                        .font(.system(.caption, design: .default))
                        .padding(4)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.5))
                        .foregroundColor(.black)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                // --- End Banner ---
                
                chatScrollView
                interactionArea
                    .padding()
                    .background(Color.backgroundCream.shadow(radius: 2))
            }
        }
        .navigationBarHidden(true)
        .alert("Reflection Error", isPresented: Binding<Bool>(
            get: { followUpLoopController.currentState.isError },
            set: { _,_ in /* No-op */ }
        ), presenting: followUpLoopController.currentState.errorMessage) { _ in
            Button("OK") {}
        } message: { message in
            Text(message).font(.system(size: 14, weight: .regular, design: .default))
        }
        .onAppear {
             // Initialize chatMessages using role/content
             if chatMessages.isEmpty {
                  let initialText = viewModel.journalEntry.entryText ?? "No transcript available"
                  chatMessages = [ChatMessage(role: .user, content: initialText)]
             }
             
            // Start loop only if not already started/finished/error
             if followUpLoopController.currentState == .idle {
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                      followUpLoopController.startLoop(for: viewModel.journalEntry)
                      print("ConversationView.onAppear: Called followUpLoopController.startLoop")
                 }
             }
             scrollToBottom()
        }
        .onReceive(followUpLoopController.$currentQuestion) { newQuestion in
            guard !newQuestion.isEmpty else { return }
            // Create ChatMessage using role/content
            let newMessage = ChatMessage(role: .assistant, content: newQuestion)
            if !chatMessages.contains(newMessage) { // Use default Equatable conformance
                 chatMessages.append(newMessage)
                 print("🤖 Appended AI message")
            }
        }
        .onReceive(followUpLoopController.$lastUserAnswer) { userAnswer in
             guard !userAnswer.isEmpty else { return }
             // Create ChatMessage using role/content
             let newMessage = ChatMessage(role: .user, content: userAnswer)
             if !chatMessages.contains(newMessage) { // Use default Equatable conformance
                  chatMessages.append(newMessage)
                  print("👤 Appended User message")
             }
         }
        .fullScreenCover(isPresented: $showSessionEndView) {
            SessionEndView(onDismiss: { 
                showSessionEndView = false // Dismiss the modal first
                dismiss() // Then dismiss the ConversationView itself
            })
        }
        .onChange(of: followUpLoopController.currentState) { _, newState in
            if newState == .finished {
                // Delay slightly to allow UI update before presenting modal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSessionEndView = true
                }
            }
        }
    }

    // MARK: - Subviews (Refactored)
    
    // Extracted Header View
    private var headerView: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.secondaryTaupe)
            }
            .padding()
        }
    }
    
    // Extracted ScrollView for Chat Messages
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(chatMessages) { message in 
                        messageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .onAppear { scrollViewProxy = proxy }
            .onChange(of: chatMessages) { _, _ in scrollToBottom() } 
        }
    }

    // Existing Message Bubble View
    @ViewBuilder
    private func messageBubble(message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            Text(message.content) // Use .content
                .font(.system(size: 16, weight: .regular, design: .default))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                 // Style based on .role
                .background(message.role == .user ? Color.buttonBrown : Color.accentPaleGrey)
                .foregroundColor(message.role == .user ? Color.backgroundCream : Color.primaryEspresso)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.role == .user ? .trailing : .leading)
            if message.role != .user {
                Spacer()
            }
        }
    }
    
    // Existing Interaction Area View
    @ViewBuilder
    private var interactionArea: some View {
        VStack {
            switch followUpLoopController.currentState {
            case .idle:
                ProgressView().tint(Color.secondaryTaupe)
            case .thinking, .processingAnswer:
                // TODO: Replace with custom thinking animation
                ProgressView("Thinking...").tint(Color.secondaryTaupe).font(.system(size: 16, weight: .regular, design: .default))
            case .showingQuestion:
                 // Button styled like WelcomeView's Get Started
                 Button("Ready to Answer") {
                     followUpLoopController.userReadyToAnswer()
                     // Add placeholder user answer for testing UI
                     // messages.append(ChatMessage(text: "Placeholder user answer text.", isUser: true))
                 }
                 .buttonStyle(PillButtonStyle())
            case .listening:
                 // Mic button styled like HomeView
                 Button { 
                      if followUpLoopController.isRecording {
                           followUpLoopController.stopRecordingAndProcess()
                      } else {
                           followUpLoopController.startRecording()
                      }
                 } label: {
                     Image(systemName: followUpLoopController.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                         .resizable()
                         .scaledToFit()
                         .frame(width: 60, height: 60) // Slightly smaller than Home
                         .foregroundColor(followUpLoopController.isRecording ? .red : Color.buttonBrown)
                         .scaleEffect(followUpLoopController.isRecording ? 1.1 : 1.0)
                         .animation(.spring(response: 0.3, dampingFraction: 0.5), value: followUpLoopController.isRecording)
                 }
                 .padding(.top, 10)
            case .finished:
                // Now just shows a minimal placeholder while the modal prepares to show
                Text("") // Empty text or a subtle indicator
                    .frame(height: 100) // Keep height consistent
            case .error(let message):
                Text("Error: \(message)")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 100) // Keep height consistent
    }
    
    // MARK: - Helpers

    private func scrollToBottom() {
        guard let proxy = scrollViewProxy, let lastMessageId = chatMessages.last?.id else { return }
        DispatchQueue.main.async {
             withAnimation {
                 proxy.scrollTo(lastMessageId, anchor: .bottom)
             }
        }
    }
}

// Reusable Pill Button Style
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(.backgroundCream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.buttonBrown)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Extensions

// Helper extension for FollowUpLoopController.LoopState
extension FollowUpLoopController.LoopState {
    var isError: Bool {
        if case .error = self { return true } else { return false }
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message } else { return nil }
    }
}

// Preview needs significant update - requires mock entry & potentially mock controller
// #Preview { ... }

