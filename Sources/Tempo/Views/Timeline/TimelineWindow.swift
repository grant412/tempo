import SwiftUI

struct TimelineWindow: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        VStack(spacing: 0) {
            TimelineToolbar()
            HStack(alignment: .top, spacing: 20) {
                ScrollView {
                    VStack(spacing: 16) {
                        WeekStripView()
                        DayStatsView()
                        CategoryListView()
                    }
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.never)
                .frame(width: 272)
                DayCanvasView().frame(maxWidth: .infinity, maxHeight: .infinity)
                InspectorView().frame(width: 330)
            }
            .padding(20)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .themed()
        .frame(minWidth: 1100, minHeight: 720)
    }
}
