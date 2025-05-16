import SwiftUI
import MessageUI // For Feedback Email

struct SupportView: View {
    
    @State private var showingFeedbackSheet = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil

    var body: some View {
        ZStack {
            Color.backgroundCream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // FAQ Section (Placeholder Link)
                    sectionHeader("Frequently Asked Questions")
                    supportLink(title: "How is my data stored?", destination: Text("FAQ Detail Placeholder"))
                    supportLink(title: "How does the AI work?", destination: Text("FAQ Detail Placeholder"))
                    supportLink(title: "Can I export my entries?", destination: Text("FAQ Detail Placeholder"))

                    Divider().padding(.vertical, 10)
                    
                    // Feedback Section
                    sectionHeader("Feedback")
                    Button {
                         if MFMailComposeViewController.canSendMail() {
                            showingFeedbackSheet = true
                         } else {
                            // Handle cases where mail is not configured
                            print("Cannot send email from this device.")
                            // Maybe show an alert?
                         }
                    } label: {
                        supportRowLabel(title: "Send Feedback Email", icon: "envelope.fill")
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.vertical, 10)

                    // Emergency Journaling (Placeholder)
                    sectionHeader("Need Immediate Support?")
                    // Example: Link to a crisis hotline website or resource
                    Link(destination: URL(string: "https://988lifeline.org")!) { // Example link
                         supportRowLabel(title: "Crisis Resources", icon: "exclamationmark.bubble.fill")
                             .foregroundColor(.red) // Highlight emergency option
                    }
                    Text("If you are in crisis or need urgent support, please reach out to a professional resource.")
                        .font(.system(size: 14, weight: .regular, design: .default)) // SF Pro
                        .foregroundColor(.secondaryTaupe)
                        .padding(.top, 5)

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.large)
        // Mail Compose Sheet
        .sheet(isPresented: $showingFeedbackSheet) {
             MailComposeView(result: $mailResult, recipients: ["feedback@heardapp.example.com"], subject: "Heard App Feedback", messageBody: "<br/><br/>---<br/>App Version: \(Bundle.main.appVersion ?? "N/A")")
                 .edgesIgnoringSafeArea(.all)
         }
    }
    
    // Helper for section headers
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .medium, design: .default)) // SF Pro
            .foregroundColor(.primaryEspresso)
            .padding(.bottom, 5)
    }
    
    // Helper for styling navigation links in the support list
    @ViewBuilder
    private func supportLink<Destination: View>(title: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            supportRowLabel(title: title, icon: "questionmark.circle.fill")
        }
    }
    
    // Helper for the row content (icon + text)
    @ViewBuilder
    private func supportRowLabel(title: String, icon: String) -> some View {
         HStack {
             Image(systemName: icon)
                 .foregroundColor(.buttonBrown)
                 .frame(width: 25)
             Text(title)
                 .font(.system(size: 17, weight: .regular, design: .default)) // SF Pro
                 .foregroundColor(.primaryEspresso)
             Spacer()
             Image(systemName: "chevron.right")
                 .foregroundColor(.secondaryTaupe.opacity(0.5))
                 .font(Font.system(.footnote, design: .default).weight(.semibold)) // Corrected SF Pro usage
         }
         .padding(.vertical, 8)
    }
}

// Mail Compose View Representable (requires import MessageUI)
struct MailComposeView: UIViewControllerRepresentable {
    @Binding var result: Result<MFMailComposeResult, Error>?
    let recipients: [String]?
    let subject: String?
    let messageBody: String?

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(result: Binding<Result<MFMailComposeResult, Error>?>) {
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                controller.dismiss(animated: true)
            }
            if let error = error {
                self.result = .failure(error)
            } else {
                self.result = .success(result)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(result: $result)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject ?? "")
        vc.setMessageBody(messageBody ?? "", isHTML: true)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}

// Helper to get app version
extension Bundle {
    var appVersion: String? {
        self.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

#Preview {
    NavigationView {
        SupportView()
    }
} 