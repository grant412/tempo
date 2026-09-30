import SwiftUI
import TempoCore

struct InspectorView: View {
    @EnvironmentObject var model: TempoModel

    var body: some View {
        VStack(spacing: 0) {
            if let block = model.selectedBlock {
                header(block)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow(text: "What was inside").padding(.bottom, 6)
                        ForEach(block.items, id: \.key) { item in
                            ItemRow(item: item, maxDuration: block.items.first?.duration ?? 1)
                        }
                        Text("Short switches under 2 minutes stay inside the block. Change any category and every day re-sorts.")
                            .font(Theme.ui(12.5)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            } else {
                Text("Nothing tracked on this day yet.")
                    .font(Theme.ui(13.5)).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let needs = model.needsCategory { NeedsCategoryPanel(needs: needs) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .background(CardSurface())
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line))
    }

    private func header(_ block: Block) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED BLOCK").font(Theme.eyebrow()).tracking(1.1)
            HStack(alignment: .firstTextBaseline) {
                Text(block.category.name).font(Theme.display(34)).kerning(-1)
                    .lineLimit(1).minimumScaleFactor(0.5).layoutPriority(1)
                Spacer()
                Text(Format.duration(block.duration)).font(Theme.display(34)).kerning(-1)
                    .fixedSize()
            }
            Text("\(Format.clock(block.start)) to \(block.isLive ? "now" : Format.clock(block.end))").font(Theme.mono(12.5))
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 18, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(block.category.labelColor)
        .background(CategoryFill(category: block.category))
    }
}

struct ItemRow: View {
    @EnvironmentObject var model: TempoModel
    @ObservedObject private var blocker = BlockEnforcer.shared
    let item: BlockItem
    let maxDuration: TimeInterval

    var body: some View {
        HStack(spacing: 8) {
            Text(String(item.displayName.prefix(1)).uppercased())
                .font(Theme.display(15))
                .frame(width: 32, height: 32)
                .background(Theme.chip, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.displayName).font(Theme.ui(13.5, .semibold)).lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Format.duration(item.duration)).font(Theme.mono(12))
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        CategoryFill(category: item.category)
                            .frame(width: max(2, g.size.width * item.duration / max(maxDuration, 1)))
                            .clipShape(Capsule())
                    }
                }
                .frame(height: 4)
            }
            if model.isLocked(item.key) {
                LockedBadge(until: blocker.distractionWindow?.end)
            } else {
                CategoryMenu(current: item.category) { model.setCategory(item.key, $0) }
            }
        }
        .padding(.vertical, 6)
    }
}

struct NeedsCategoryPanel: View {
    @EnvironmentObject var model: TempoModel
    let needs: TempoModel.NeedsCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Needs a category")
            HStack(spacing: 10) {
                StripeFill().frame(width: 32, height: 20).clipShape(RoundedRectangle(cornerRadius: 5))
                (Text(needs.name).font(Theme.mono(13, .semibold))
                    + Text(", \(Format.duration(needs.duration)) \(model.isShowingToday ? "today" : "that day")").font(Theme.ui(13.5)))
                    .lineLimit(1).truncationMode(.middle)
            }
            FlowLayout(spacing: 6) {
                ForEach(model.quickCategories, id: \.self) { c in
                    CategoryChip(category: c) { model.setCategory(needs.key, c) }
                }
                Menu {
                    ForEach(CategoryID.assignable, id: \.self) { c in
                        Button(c.name) { model.setCategory(needs.key, c) }
                    }
                } label: {
                    Text("More").font(Theme.ui(12.5, .semibold))
                        .padding(.horizontal, 10).frame(height: 28)
                        .contentShape(Capsule())
                        .overlay(Capsule().stroke(Theme.line))
                        .foregroundStyle(Theme.ink)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 16, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
