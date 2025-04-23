import Foundation
import CoreData
import Combine
import SwiftUI

@MainActor
class ConversationViewModel: ObservableObject {
    let journalEntry: JournalEntryCD
    private let context: NSManagedObjectContext
    private let coreDataStorage: JournalStorage
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State
    @Published var followUps: [FollowUpCD] = []
    @Published var isLoadingQuestions: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    @Published var canAskMore: Bool = true

    // MARK: - Initialization
    init(journalEntry: JournalEntryCD, context: NSManagedObjectContext) {
        self.journalEntry = journalEntry
        self.context = context
        self.coreDataStorage = CoreDataStorage(context: context)
        print("ConversationViewModel initialized for entry ID: \(journalEntry.id?.uuidString ?? "N/A")")
    }

    // MARK: - Data Loading
    func loadFollowUps() {
        if let related = journalEntry.followups?.allObjects as? [FollowUpCD] {
            followUps = related.sorted(by: { $0.createdAt ?? Date.distantPast < $1.createdAt ?? Date.distantPast })
            print("Loaded \(followUps.count) follow-ups from Core Data.")
        } else {
            followUps = []
            print("No existing follow-ups found or relationship not set.")
        }
        checkIfCanAskMore()
    }

    // MARK: - GPT Generation
    func generateFollowUpQuestions() {
        guard canAskMore else {
            print("🛑 Not generating question: canAskMore is false.")
            return
        }
        guard !isLoadingQuestions else {
            print("🏃 Already generating questions, skipping.")
            return
        }
        guard NetworkMonitor.shared.isConnected else {
            handleError("You appear to be offline. Please connect to Wi-Fi or cellular.", isOffline: true)
            return
        }

        isLoadingQuestions = true
        errorMessage = nil
        showErrorAlert = false

        Task {
            defer { isLoadingQuestions = false }

            guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAI_API_Key") as? String,
                  !apiKey.isEmpty,
                  !apiKey.starts(with: "YOUR_") else {
                handleError("OpenAI API Key is missing, empty, or a placeholder in Info.plist. Please configure it correctly.")
                return
            }

            guard let entryText = journalEntry.entryText, !entryText.isEmpty else {
                handleError("Cannot generate follow-up for empty entry.")
                return
            }

            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var messages: [[String: String]] = [
                ["role": "system", "content": "You are a reflective journaling assistant. Ask one concise, open-ended follow-up question at a time based on the journal entry and previous questions/answers. Avoid generic questions. Stop asking when the user seems finished or the reflection becomes circular. Indicate you are finished by saying something like 'Is there anything else on your mind about this?' or 'Let me know if you'd like to explore further.'"],
                ["role": "user", "content": "Here is my journal entry:\n\n\(entryText)"]
            ]
            for followUp in followUps {
                if !followUp.question.isEmpty {
                    messages.append(["role": "assistant", "content": followUp.question])
                }
                if let answer = followUp.answer, !answer.isEmpty {
                    messages.append(["role": "user", "content": answer])
                }
            }
            messages.append(["role": "system", "content": "Now, ask the next single follow-up question based on the conversation so far."])

            let requestBody: [String: Any] = [
                "model": "gpt-4",
                "messages": messages,
                "max_tokens": 60,
                "temperature": 0.75,
                "stop": ["\n"]
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    if let errorData = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                        handleError("GPT API Error: \(errorData.error.message)")
                    } else {
                        handleError("GPT API Error: Received status code \(statusCode).")
                    }
                    return
                }

                let openAIResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                guard var generatedQuestion = openAIResponse.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !generatedQuestion.isEmpty else {
                    handleError("Failed to get follow-up question from GPT response.")
                    return
                }

                if generatedQuestion.hasPrefix("\"") && generatedQuestion.hasSuffix("\"") {
                    generatedQuestion = String(generatedQuestion.dropFirst().dropLast())
                }

                if detectStopPhrase(in: generatedQuestion) {
                    canAskMore = false
                } else {
                    try coreDataStorage.saveFollowUp(question: generatedQuestion, for: journalEntry)
                    loadFollowUps()
                    canAskMore = true
                }

            } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .timedOut].contains(error.code) {
                handleError("Unable to generate reflections. Please check your internet connection.", isOffline: true)
            } catch {
                handleError("Failed to generate follow-up: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Answer Saving
    func saveAnswer(for followUp: FollowUpCD, answer: String) {
        print("💾 Saving answer for FollowUp ID: \(String(describing: followUp.id)): \(answer)")
        followUp.answer = answer
        do {
            try context.save()
            print("✅ Answer saved successfully.")
        } catch {
            handleError("Failed to save your answer.")
            context.rollback()
        }
    }

    // MARK: - Helpers
    private func handleError(_ message: String, isOffline: Bool = false) {
        self.errorMessage = message
        self.showErrorAlert = true
        if isOffline {
            self.canAskMore = false
        }
    }

    private func detectStopPhrase(in text: String) -> Bool {
        let lowercasedText = text.lowercased()
        let stopPhrases = [
            "anything else on your mind",
            "anything else you want to share",
            "explore further",
            "anything else i can help with",
            "like to discuss more",
            "no more questions"
        ]
        return stopPhrases.contains { lowercasedText.contains($0) }
    }

    private func checkIfCanAskMore() {
        if let lastQuestion = followUps.last?.question, detectStopPhrase(in: lastQuestion) {
            canAskMore = false
        } else {
            canAskMore = true
        }
    }
}
