import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    @State private var defaultReaderFont: String = "New York"
    @State private var defaultThemeName: String = "Light"
    @State private var autoArchiveStories: Bool = false
    @State private var cacheCleared: Bool = false
    @State private var navigateToProfile: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.warmCream.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // User Profile Card (tappable to view Profile)
                            Button(action: {
                                navigateToProfile = true
                            }) {
                                HStack(spacing: 14) {
                                    if let avatar = UIImage(named: "avatar_roosc") {
                                        Image(uiImage: avatar)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 54, height: 54)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(FableTheme.softPeach)
                                            .frame(width: 54, height: 54)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Roosc Zaño")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                        
                                        Text("roosc-zano@fable.app")
                                            .font(.system(size: 13))
                                            .foregroundColor(FableTheme.subtleSlate)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color.gray.opacity(0.4))
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            .buttonStyle(.plain)
                            
                            // Reading Preferences Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("READING PREFERENCES")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.subtleSlate)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    // Default Reader Font
                                    HStack(spacing: 14) {
                                        Image(systemName: "character.textbox")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                            .frame(width: 32, height: 32)
                                            .background(Color.gray.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Default Reader Font")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            Text(defaultReaderFont)
                                                .font(.system(size: 14))
                                                .foregroundColor(FableTheme.subtleSlate)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.gray.opacity(0.4))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)
                                    
                                    // Default Theme
                                    HStack(spacing: 14) {
                                        Image(systemName: "paintpalette")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                            .frame(width: 32, height: 32)
                                            .background(Color.gray.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Default Theme")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 6) {
                                            Circle()
                                                .stroke(FableTheme.lightBorder, lineWidth: 1)
                                                .fill(Color.white)
                                                .frame(width: 14, height: 14)
                                            Text(defaultThemeName)
                                                .font(.system(size: 14))
                                                .foregroundColor(FableTheme.subtleSlate)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.gray.opacity(0.4))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider().padding(.leading, 62)
                                    
                                    // Haptic Feedback Toggle
                                    HStack(spacing: 14) {
                                        Image(systemName: "iphone.radiowaves.left.and.right")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                            .frame(width: 32, height: 32)
                                            .background(Color.gray.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Haptic Feedback")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $store.hapticFeedback)
                                            .tint(FableTheme.terracotta)
                                            .labelsHidden()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            
                            // Shelf & Library Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SHELF & LIBRARY")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.subtleSlate)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    // Downloaded Stories
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Downloaded Stories")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(FableTheme.deepCharcoal)
                                            Text(cacheCleared ? "0 Tales (0 MB)" : "12 Tales (42 MB)")
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.subtleSlate)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation {
                                                cacheCleared = true
                                            }
                                        }) {
                                            Text(cacheCleared ? "Cleared" : "Clear Cache")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(FableTheme.deepCharcoal)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.gray.opacity(0.12))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    Divider()
                                    
                                    // Auto-Archive Stories
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Auto-Archive Stories")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(FableTheme.deepCharcoal)
                                            Text("Move completed tales out of shelf view")
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.subtleSlate)
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $autoArchiveStories)
                                            .tint(FableTheme.terracotta)
                                            .labelsHidden()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            
                            // Sign Out Card Button
                            Button(action: {}) {
                                Text("Sign Out")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(FableTheme.deepCharcoal)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(FableTheme.terracotta)
                }
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                ProfileView()
                    .environmentObject(store)
            }
        }
    }
}
