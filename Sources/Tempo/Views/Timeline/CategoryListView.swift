import SwiftUI
import TempoCore

struct CategoryListView: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        VStack(spacing: 2) {
            if let top = model.summary.categories.first {
                ForEach(model.summary.categories, id: \.category) { total in
                    CategoryBarRow(total: total, maxDuration: top.duration)
                }
            } else {
                Text("No activity on this day.").font(Theme.ui(13)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
    }
}
