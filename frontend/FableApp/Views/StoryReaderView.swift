import SwiftUI

/// Architectural mapping for Story Reader Screen (ARCHITECTURE.md Section 8, Screen 2; FIGMA.md Frame 1:159)
public struct StoryReaderView: View {
    public let story: Story
    
    public init(story: Story) {
        self.story = story
    }
    
    public var body: some View {
        ReaderView(story: story)
    }
}
