import SwiftUI
import AVFoundation
import AVFAudio

struct DisplayOptionsSheet: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var narrator = AudioNarratorController.shared
    @State private var isShowingVoiceSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
            
            // Header
            HStack {
                Button("Reset") {
                    store.resetDisplayOptions()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(FableTheme.terracotta)
                
                Spacer()
                
                Text("Display Options")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(FableTheme.deepCharcoal)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(FableTheme.subtleSlate)
                        .padding(8)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            
            // Typography Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TYPOGRAPHY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(FableTheme.subtleSlate)
                    
                    Spacer()
                    
                    Text(store.readerFont.displayName)
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(FableTheme.terracotta)
                }
                
                HStack(spacing: 0) {
                    ForEach(ReaderFont.allCases) { font in
                        Button(action: {
                            store.readerFont = font
                        }) {
                            Text(font.rawValue)
                                .font(font.font(size: 14))
                                .fontWeight(store.readerFont == font ? .semibold : .regular)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(store.readerFont == font ? Color.white : Color.clear)
                                .foregroundColor(store.readerFont == font ? FableTheme.deepCharcoal : FableTheme.subtleSlate)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: store.readerFont == font ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                        }
                    }
                }
                .padding(4)
                .background(Color.gray.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            
            // Text Size Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TEXT SIZE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(FableTheme.subtleSlate)
                    
                    Spacer()
                    
                    Text("\(Int(store.readerFontSize))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FableTheme.subtleSlate)
                }
                
                HStack(spacing: 16) {
                    Text("A")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundColor(FableTheme.subtleSlate)
                    
                    Slider(value: $store.readerFontSize, in: 80...150, step: 5)
                        .tint(FableTheme.terracotta)
                    
                    Text("A")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(FableTheme.deepCharcoal)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            
            // Reading Background Section
            VStack(alignment: .leading, spacing: 12) {
                Text("READING BACKGROUND")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(FableTheme.subtleSlate)
                
                HStack(spacing: 0) {
                    ForEach(ReaderTheme.allCases) { theme in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(theme.swatchColor)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(store.readerTheme == theme ? FableTheme.terracotta : FableTheme.lightBorder, lineWidth: store.readerTheme == theme ? 2 : 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
                                
                                if store.readerTheme == theme {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(theme == .oled || theme == .charcoal ? .white : FableTheme.terracotta)
                                }
                            }
                            
                            Text(theme.rawValue)
                                .font(.system(size: 12, weight: store.readerTheme == theme ? .semibold : .regular))
                                .foregroundColor(store.readerTheme == theme ? FableTheme.deepCharcoal : FableTheme.subtleSlate)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            store.readerTheme = theme
                        }
                    }
                }
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            
            // Line Spacing Section
            VStack(alignment: .leading, spacing: 12) {
                Text("LINE SPACING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(FableTheme.subtleSlate)
                
                HStack(spacing: 12) {
                    ForEach(ReaderLineSpacing.allCases) { spacing in
                        Button(action: {
                            store.readerLineSpacing = spacing
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: spacingIcon(for: spacing))
                                    .font(.system(size: 13))
                                Text(spacing.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(store.readerLineSpacing == spacing ? FableTheme.softPeach : Color.gray.opacity(0.07))
                            .foregroundColor(store.readerLineSpacing == spacing ? FableTheme.terracotta : FableTheme.deepCharcoal)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(store.readerLineSpacing == spacing ? FableTheme.terracotta.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Reading Mode Section (Plan 03: Authentic Pagination)
            VStack(alignment: .leading, spacing: 10) {
                Text("READING LAYOUT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(FableTheme.subtleSlate)
                
                HStack(spacing: 12) {
                    Button(action: {
                        store.isPaginatedMode = false
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "scroll")
                            Text("Scroll")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(!store.isPaginatedMode ? FableTheme.softPeach : Color.gray.opacity(0.07))
                        .foregroundColor(!store.isPaginatedMode ? FableTheme.terracotta : FableTheme.deepCharcoal)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(!store.isPaginatedMode ? FableTheme.terracotta.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button(action: {
                        store.isPaginatedMode = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.pages")
                            Text("Paginated Book")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(store.isPaginatedMode ? FableTheme.softPeach : Color.gray.opacity(0.07))
                        .foregroundColor(store.isPaginatedMode ? FableTheme.terracotta : FableTheme.deepCharcoal)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(store.isPaginatedMode ? FableTheme.terracotta.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 20)

            // Oral Folklore Narrator Voice Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("NARRATOR VOICE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(FableTheme.subtleSlate)
                    
                    Spacer()
                    
                    Button(action: {
                        isShowingVoiceSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Text(currentVoiceDisplayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(FableTheme.terracotta)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(FableTheme.terracotta)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .presentationDetents([.fraction(0.88), .large])
        .presentationDragIndicator(.hidden)
        .background(Color.white)
        .sheet(isPresented: $isShowingVoiceSheet) {
            VoiceSelectionSheet()
        }
    }
    
    private var currentVoiceDisplayName: String {
        if let id = narrator.selectedVoiceIdentifier,
           let voice = narrator.availableVoices.first(where: { $0.identifier == id }) {
            return "\(voice.name)"
        }
        return "System Default (en-US)"
    }
    
    private func spacingIcon(for spacing: ReaderLineSpacing) -> String {
        switch spacing {
        case .compact: return "text.alignleft"
        case .normal: return "arrow.up.and.down.text.horizontal"
        case .spacious: return "distribute.vertical.top"
        }
    }
}
