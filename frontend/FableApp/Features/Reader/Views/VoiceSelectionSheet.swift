import SwiftUI
import AVFoundation

public struct VoiceSelectionSheet: View {
    @ObservedObject var narrator = AudioNarratorController.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(narrator.availableVoices, id: \.identifier) { voice in
                        Button(action: {
                            narrator.setVoice(identifier: voice.identifier)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(voice.name)
                                            .font(.system(size: 15, weight: isSelected(voice) ? .bold : .medium))
                                            .foregroundColor(isSelected(voice) ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                        
                                        if voice.quality == .enhanced || voice.quality == .premium {
                                            Text("HD")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(FableTheme.brandPrimary.opacity(0.12))
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        }
                                    }
                                    
                                    Text("\(regionName(for: voice.language)) • \(voice.language)")
                                        .font(.system(size: 12))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                
                                Spacer()
                                
                                if isSelected(voice) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(FableTheme.brandPrimary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Available Folklore Narrators")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FableTheme.textMuted)
                } footer: {
                    Text("Voice engines are provided by the operating system speech synthesis service.")
                        .font(.system(size: 11))
                        .foregroundColor(FableTheme.textMuted)
                }
            }
            .navigationTitle("Narrator Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func isSelected(_ voice: AVSpeechSynthesisVoice) -> Bool {
        if let currentId = narrator.selectedVoiceIdentifier {
            return currentId == voice.identifier
        }
        return voice.language == "en-US" && voice.name.contains("Samantha")
    }
    
    private func regionName(for languageCode: String) -> String {
        let locale = Locale(identifier: languageCode)
        if let region = locale.localizedString(forIdentifier: languageCode) {
            return region
        }
        return languageCode
    }
}
