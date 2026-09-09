import CoreGraphics

struct ArenaDeveloperTuningLayout {
    let group: CGRect
    let subgroup: CGRect
    let parameters: CGRect

    init(contentFrame: CGRect) {
        let columnGap: CGFloat = contentFrame.width < 620 ? 8 : 12
        let groupWidth = min(126, max(102, contentFrame.width * 0.2))
        let subgroupWidth = min(148, max(116, contentFrame.width * 0.23))
        group = CGRect(
            x: contentFrame.minX,
            y: contentFrame.minY,
            width: groupWidth,
            height: contentFrame.height
        )
        subgroup = CGRect(
            x: group.maxX + columnGap,
            y: contentFrame.minY,
            width: subgroupWidth,
            height: contentFrame.height
        )
        parameters = CGRect(
            x: subgroup.maxX + columnGap,
            y: contentFrame.minY,
            width: max(0, contentFrame.maxX - subgroup.maxX - columnGap),
            height: contentFrame.height
        )

    }

    var pageSize: Int {
        let usableHeight = max(0, parameters.height - 76)
        return max(1, Int(floor(usableHeight / Self.rowHeight(in: parameters))))
    }

    static func rowHeight(in frame: CGRect) -> CGFloat {
        frame.height < 230 ? 28 : 32
    }
}
