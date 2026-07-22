import SwiftUI

/// One gesture vocabulary for every wave surface (design §03 + amendment A1):
/// horizontal drag scrolls all lanes (disengages follow), pinch zooms about the
/// centroid, tap seeks every lane. Applied to wave canvases only — never over
/// controls — as a size-matching overlay, so lane layout is untouched.
struct WaveTimelineGestures: ViewModifier {
    let model: StemPlayerModel

    @State private var isPanning = false
    @State private var isZooming = false

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(tapGesture(width: proxy.size.width))
                    .gesture(panGesture(width: proxy.size.width))
                    .simultaneousGesture(zoomGesture())
            }
        }
    }

    private func panGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                // Horizontal-dominant drags own the timeline; verticals are ignored
                // so the surrounding scroll view can take them.
                guard isPanning || abs(value.translation.width) > abs(value.translation.height) else { return }
                if !isPanning {
                    isPanning = true
                    model.panBegan(at: Date())
                }
                model.panChanged(translationX: value.translation.width, width: width, at: Date())
            }
            .onEnded { _ in
                isPanning = false
                model.panEnded()
            }
    }

    private func zoomGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !isZooming {
                    isZooming = true
                    model.zoomBegan()
                }
                model.zoomChanged(
                    magnification: value.magnification,
                    centroidFraction: Double(value.startAnchor.x),
                    at: Date()
                )
            }
            .onEnded { _ in
                isZooming = false
                model.zoomEnded()
            }
    }

    private func tapGesture(width: CGFloat) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard width > 0 else { return }
                model.tapSeek(fractionOfWidth: Double(value.location.x / width), at: Date())
            }
    }
}

extension View {
    /// Attach to a wave canvas surface (and only a wave canvas surface).
    func waveTimelineGestures(_ model: StemPlayerModel) -> some View {
        modifier(WaveTimelineGestures(model: model))
    }
}
