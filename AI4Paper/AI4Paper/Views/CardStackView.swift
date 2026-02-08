import SwiftUI

struct CardStackView: View {
    let papers: [Paper]
    let onLike: (Paper) -> Void
    let onDislike: (Paper) -> Void

    @State private var dragOffset: CGSize = .zero

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            if papers.count > 1 {
                PaperCardView(paper: papers[1])
                    .scaleEffect(0.97)
                    .offset(y: 12)
            }

            if let current = papers.first {
                PaperCardView(paper: current)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 12)))
                    .overlay(swipeOverlay)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                handleDragEnd(value: value, paper: current)
                            }
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swipeOverlay: some View {
        HStack {
            if dragOffset.width > 40 {
                swipeBadge(text: "SAVE", color: .green)
                Spacer()
            } else if dragOffset.width < -40 {
                Spacer()
                swipeBadge(text: "NOPE", color: .red)
            }
        }
        .padding()
        .opacity(min(abs(dragOffset.width) / CGFloat(120), CGFloat(1)))


    }

    private func swipeBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 2)
            )
            .foregroundStyle(color)
    }

    private func handleDragEnd(value: DragGesture.Value, paper: Paper) {
        if value.translation.width > swipeThreshold {
            onLike(paper)
        } else if value.translation.width < -swipeThreshold {
            onDislike(paper)
        }

        dragOffset = .zero
    }
}
