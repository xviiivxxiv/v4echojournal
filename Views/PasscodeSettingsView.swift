import SwiftUI
import LocalAuthentication

struct PasscodeSettingsView: View {
    @State private var isPasscodeSet: Bool = false
    @EnvironmentObject var settings: SettingsManager
    
    // State for presenting the setup sheet
    @State private var isSettingUpPasscode = false
    
    var body: some View {
        Form {
            Section(header: Text("Passcode Lock")) {
                // If passcode is set, show options to turn off or change
                if isPasscodeSet {
                    Button("Turn Passcode Off") {
                        // Action to remove passcode
                        if KeychainService.deletePasscode() {
                            isPasscodeSet = false
                            settings.isFaceIDEnabled = false // Also disable Face ID
                        }
                    }
                    .foregroundColor(.red)

                    Button("Change Passcode") {
                        // This would also present the setup view, but in a 'change' mode
                        isSettingUpPasscode = true
                    }
                    
                } else {
                    // If no passcode, show option to turn it on
                    Button("Turn Passcode On") {
                        isSettingUpPasscode = true
                    }
                }
            }
            
            // Only show Face ID option if a passcode is set
            if isPasscodeSet {
                Section(header: Text("Biometrics")) {
                    Toggle("Enable Face ID", isOn: $settings.isFaceIDEnabled)
                        .tint(Color.buttonBrown)
                        .onChange(of: settings.isFaceIDEnabled) { oldValue, newValue in
                            print("🔧 Face ID toggle changed: \(oldValue) → \(newValue)")
                            print("🔧 UserDefaults after change: \(UserDefaults.standard.bool(forKey: "isFaceIDEnabled"))")
                            if newValue {
                                authenticateWithBiometrics()
                            }
                        }
                }
            }
        }
        .navigationTitle("Passcode & Face ID")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: checkPasscodeStatus)
        .sheet(isPresented: $isSettingUpPasscode) {
            // This will be the view to enter/confirm a passcode
            // We pass a callback to update our state when setup is complete.
            PasscodeSetupView(isPresented: $isSettingUpPasscode, onComplete: {
                // After setup completes successfully, update the state
                self.isPasscodeSet = true
            })
        }
    }
    
    private func checkPasscodeStatus() {
        if KeychainService.getPasscode() != nil {
            isPasscodeSet = true
        } else {
            isPasscodeSet = false
        }
    }
    
    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Enable Face ID to quickly unlock your journal."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // This is just for enabling. The actual usage of Face ID
                        // will happen on app launch.
                        print("Biometric authentication successful.")
                    } else {
                        print("Biometric authentication failed.")
                        // If user fails, revert the toggle
                        self.settings.isFaceIDEnabled = false
                    }
                }
            }
        } else {
            // No biometrics available
            print("Biometrics not available.")
            self.settings.isFaceIDEnabled = false
        }
    }
}

// MARK: - Passcode Setup View
struct PasscodeSetupView: View {
    enum SetupStep {
        case enter, confirm
    }
    
    @Binding var isPresented: Bool
    var onComplete: () -> Void
    
    @State private var step: SetupStep = .enter
    @State private var newPasscode: String = ""
    @State private var confirmationPasscode: String = ""
    @State private var title: String = "Enter a new passcode"
    @State private var didFailConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            
            // Heard logo
            Image("Heard Logo - Cream - Transparent - Landscape")
                .resizable()
                .scaledToFit()
                .frame(height: 30) // Small, subtle logo
                .padding(.bottom, 40)
            
            Text(title)
                .font(.custom("GentyDemo-Regular", size: 34))
                .foregroundColor(.primary)
                .padding(.bottom, 60)
                .animation(.easeInOut(duration: 0.3), value: title) // Smooth title transition
            
            PasscodeIndicator(passcode: step == .enter ? newPasscode : confirmationPasscode)
                .modifier(Shake(animatableData: CGFloat(didFailConfirmation ? 1 : 0)))
                .padding(.bottom, 60)
                .animation(.easeInOut(duration: 0.3), value: step) // Smooth indicator transition
            
            Spacer()
            
            NumberPad(
                onNumberTapped: handleInput,
                onFaceIDTapped: nil,
                showFaceID: false
            )
            
            Button("Cancel") {
                isPresented = false
            }
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(.buttonBrown)
            .padding(.top, 30)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondaryTaupe.ignoresSafeArea())
    }
    
    private func handleInput(_ digit: String) {
        if digit == "⌫" {
            handleBackspace()
            return
        }

        if step == .enter {
            if newPasscode.count < 4 {
                newPasscode += digit
                
                // Auto-advance to confirmation step when 4 digits entered
                if newPasscode.count == 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .confirm
                            title = "Re-enter passcode"
                        }
                    }
                }
            }
        } else {
            if confirmationPasscode.count < 4 {
                confirmationPasscode += digit
                if confirmationPasscode.count == 4 {
                    verifyPasscode()
                }
            }
        }
    }
    
    private func handleBackspace() {
        if step == .enter {
            if !newPasscode.isEmpty {
                newPasscode.removeLast()
            }
        } else {
            if !confirmationPasscode.isEmpty {
                confirmationPasscode.removeLast()
            }
        }
    }
    
    private func verifyPasscode() {
        if newPasscode == confirmationPasscode {
            // Success! Save to keychain
            if KeychainService.save(passcode: newPasscode) {
                print("Passcode setup successful.")
                onComplete()
                isPresented = false
            } else {
                // Handle keychain save error
                title = "Could not save passcode. Try again."
                resetPasscodes()
            }
        } else {
            // Failure, shake and reset
            withAnimation(.default) {
                self.didFailConfirmation = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.didFailConfirmation = false
                self.title = "Passcodes didn't match. Try again."
                self.resetPasscodes()
            }
        }
    }
    
    private func resetPasscodes() {
        step = .enter
        newPasscode = ""
        confirmationPasscode = ""
    }
}

// MARK: - Supporting Views for Passcode

struct PasscodeIndicator: View {
    var passcode: String
    private let maxDigits = 4
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<maxDigits, id: \.self) { index in
                Circle()
                    .fill(index < passcode.count ? Color.primary : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 1.5)
                    )
                    .frame(width: 14, height: 14)
            }
        }
    }
}

struct NumberPad: View {
    var onNumberTapped: (String) -> Void
    var onFaceIDTapped: (() -> Void)? = nil
    var showFaceID: Bool = false
    
    let numbers = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(numbers, id: \.self) { row in
                HStack(spacing: 30) {
                    ForEach(row, id: \.self) { number in
                        if number.isEmpty && row == ["", "0", "⌫"] && showFaceID {
                            // Face ID button in place of empty space
                            Button(action: {
                                onFaceIDTapped?()
                            }) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundColor(.primary)
                                    .frame(width: 80, height: 80)
                                    .background(Color.white.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        } else {
                            Button(action: {
                                if !number.isEmpty {
                                    onNumberTapped(number)
                                }
                            }) {
                                Group {
                                    if number == "⌫" {
                                        Image(systemName: "delete.left")
                                            .font(.system(size: 24, weight: .regular))
                                    } else {
                                        Text(number)
                                            .font(.system(size: 30, weight: .regular, design: .default))
                                    }
                                }
                                .foregroundColor(.primary)
                                .frame(width: 80, height: 80)
                                .background(
                                    number.isEmpty ? Color.clear : Color.white.opacity(0.5)
                                )
                                .clipShape(Circle())
                            }
                            .disabled(number.isEmpty && !(number.isEmpty && row == ["", "0", "⌫"] && showFaceID))
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    NavigationView {
        PasscodeSettingsView()
    }
} 