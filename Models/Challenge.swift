import SwiftUI

// MARK: - Challenge Data Model
struct Challenge: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var subtitle: String
    var iconName: String
    var themeColor: Color
    var durationInDays: Int
    var difficulty: String
    var participantCount: Int
    var whatToExpect: [String]
    var description: String
    var dailyPrompts: [String]
    
    // Gradient for the card background
    var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [themeColor.opacity(0.6), themeColor.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Sample Challenge Data
struct ChallengeData {
    static let samples: [Challenge] = [
        Challenge(
            title: "Gratitude 7-day Challenge",
            subtitle: "Learn how to notice simple joys of life with gratitude practice.",
            iconName: "heart.fill", // Using SF Symbols for now
            themeColor: Color.orange.opacity(0.8),
            durationInDays: 7,
            difficulty: "Easy",
            participantCount: 28412,
            whatToExpect: [
                "Boost happiness level",
                "Build emotional resilience",
                "Reduce stress levels",
                "Receive report with highlights at the end"
            ],
            description: "In this 7-day challenge, you'll explore how to practice gratitude by focusing on the simple joys of life.",
            dailyPrompts: [
                "What's a simple pleasure you enjoyed today?",
                "Who is someone you're grateful for and why?",
                "What is something beautiful you saw recently?",
                "What skill are you thankful to have?",
                "What's a food you're grateful for today?",
                "What's a part of nature you appreciate?",
                "Reflect on a happy memory you're grateful for."
            ]
        ),
        Challenge(
            title: "Love Challenge",
            subtitle: "Discover your personal love languages and relationship needs.",
            iconName: "arrow.through.heart.fill", // Using SF Symbols for now
            themeColor: Color.pink.opacity(0.8),
            durationInDays: 4,
            difficulty: "Easy",
            participantCount: 38946,
            whatToExpect: [
                "Discover your love languages",
                "Define your relationships needs",
                "Identify what makes you feel loved",
                "Receive a Love Report with highlights at the end"
            ],
            description: "In this challenge, you'll explore how you experience love – both in giving and receiving.",
            dailyPrompts: [
                "How do you prefer to receive affection from others?",
                "What makes you feel most appreciated in a relationship?",
                "Describe a time you felt truly loved.",
                "How do you show love to the important people in your life?"
            ]
        ),
        Challenge(
            title: "Journaling Beginner Challenge",
            subtitle: "Build a consistent journaling habit in just one week.",
            iconName: "star.book.fill", // Using SF Symbols for now
            themeColor: Color.blue.opacity(0.8),
            durationInDays: 7,
            difficulty: "Beginner",
            participantCount: 15234,
            whatToExpect: [
                "Establish a daily routine",
                "Explore different journaling styles",
                "Reflect on your daily progress",
                "Finish with a newfound habit"
            ],
            description: "This 7-day beginner challenge is designed to help you build a consistent and fulfilling journaling habit.",
            dailyPrompts: [
                "What is one goal you want to achieve this week?",
                "Write about a small victory you had today.",
                "Describe a place where you feel completely at ease.",
                "What is something that made you laugh recently?",
                "Write a letter to your future self.",
                "What new thing did you learn today?",
                "Reflect on your week. What was the high point?"
            ]
        )
    ]
} 