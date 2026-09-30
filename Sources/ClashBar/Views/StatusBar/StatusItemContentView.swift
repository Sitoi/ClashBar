import AppKit

@MainActor
final class StatusItemContentView {
    private let iconSize: CGFloat = 24
    private let brandIconRenderSize: CGFloat = 24
    private let symbolPointSize: CGFloat = 20
    private let iconTextSpacing: CGFloat = 0
    private let textContainerWidth: CGFloat = 43
    private let textLineHeight: CGFloat = 11

    private static let renderScales: [CGFloat] = [1, 2, 3]

    private var currentDisplay: MenuBarDisplay?
    private var cachedRunBrandStatusIconImage: NSImage?
    private var cachedSleepBrandStatusIconImage: NSImage?
    private var cachedTunBrandStatusIconImage: NSImage?

    private(set) var image: NSImage?

    private var runBrandStatusIconImage: NSImage? {
        if let cached = self.cachedRunBrandStatusIconImage {
            return cached
        }
        guard let img = Self.makeBrandStatusIconImage(source: BrandIcon.runImage, size: self.brandIconRenderSize)
        else { return nil }
        self.cachedRunBrandStatusIconImage = img
        return img
    }

    private var sleepBrandStatusIconImage: NSImage? {
        if let cached = self.cachedSleepBrandStatusIconImage {
            return cached
        }
        guard let img = Self.makeBrandStatusIconImage(source: BrandIcon.sleepImage, size: self.brandIconRenderSize)
        else { return nil }
        self.cachedSleepBrandStatusIconImage = img
        return img
    }

    private var tunBrandStatusIconImage: NSImage? {
        if let cached = self.cachedTunBrandStatusIconImage {
            return cached
        }
        guard let img = Self.makeBrandStatusIconImage(source: BrandIcon.tunImage, size: self.brandIconRenderSize)
        else { return nil }
        self.cachedTunBrandStatusIconImage = img
        return img
    }

    var usesBrandIcon: Bool {
        self.runBrandStatusIconImage != nil || self.sleepBrandStatusIconImage != nil
    }

    var requiredWidth: CGFloat {
        let display = self.currentDisplay ?? MenuBarDisplay(
            mode: .iconOnly,
            symbolName: "bolt.slash.circle",
            speedLines: nil,
            isRunning: false,
            isTunEnabled: false)
        switch display.mode {
        case .iconOnly:
            return self.iconSize
        case .iconAndSpeed:
            return self.iconSize + self.iconTextSpacing + self.textContainerWidth
        case .speedOnly:
            return self.textContainerWidth
        }
    }

    func apply(display: MenuBarDisplay) {
        self.currentDisplay = display

        let iconImage: NSImage? = display.mode == .speedOnly
            ? nil
            : self.iconImage(for: display)

        let upLine = display.speedLines?.up ?? ""
        let downLine = display.speedLines?.down ?? ""
        let showsSpeed = display.mode != .iconOnly

        self.image = self.composeImage(
            iconImage: iconImage,
            upLine: showsSpeed ? upLine : "",
            downLine: showsSpeed ? downLine : "",
            showsIcon: display.mode != .speedOnly,
            showsSpeed: showsSpeed)
    }

    private func iconImage(for display: MenuBarDisplay) -> NSImage? {
        if let brandIcon = self.brandStatusIconImage(
            isRunning: display.isRunning, isTunEnabled: display.isTunEnabled)
        {
            return brandIcon
        }
        guard let symbolName = display.symbolName else { return nil }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ClashBar")
        let config = NSImage.SymbolConfiguration(pointSize: self.symbolPointSize, weight: .semibold)
        return image?.withSymbolConfiguration(config)
    }

    private func brandStatusIconImage(isRunning: Bool, isTunEnabled: Bool) -> NSImage? {
        guard isRunning else { return self.sleepBrandStatusIconImage }
        return isTunEnabled
            ? (self.tunBrandStatusIconImage ?? self.runBrandStatusIconImage)
            : self.runBrandStatusIconImage
    }

    private struct SpeedLayout {
        let up: String
        let down: String
        let originX: CGFloat
    }

    private func composeImage(
        iconImage: NSImage?,
        upLine: String,
        downLine: String,
        showsIcon: Bool,
        showsSpeed: Bool) -> NSImage
    {
        let height = NSStatusBar.system.thickness
        let size = NSSize(width: self.requiredWidth, height: height)
        let textOriginX = (showsIcon && showsSpeed) ? (self.iconSize + self.iconTextSpacing) : 0
        let speed = showsSpeed ? SpeedLayout(up: upLine, down: downLine, originX: textOriginX) : nil

        let composed = NSImage(size: size)
        for scale in Self.renderScales {
            guard let rep = self.makeRepresentation(
                iconImage: showsIcon ? iconImage : nil,
                speed: speed,
                pointSize: size,
                scale: scale)
            else { continue }
            composed.addRepresentation(rep)
        }
        composed.isTemplate = true
        return composed
    }

    private func makeRepresentation(
        iconImage: NSImage?,
        speed: SpeedLayout?,
        pointSize: NSSize,
        scale: CGFloat) -> NSBitmapImageRep?
    {
        let pixelWidth = max(1, Int((pointSize.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((pointSize.height * scale).rounded(.up)))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        else { return nil }

        rep.size = pointSize
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        if let iconImage {
            let iconRect = CGRect(
                x: 0,
                y: floor((pointSize.height - self.iconSize) / 2),
                width: self.iconSize,
                height: self.iconSize)
            let drawRect = Self.aspectFitRect(imageSize: iconImage.size, in: iconRect)
            iconImage.draw(
                in: drawRect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: nil)
        }

        if let speed, speed.up.isEmpty == false || speed.down.isEmpty == false {
            self.drawSpeedText(speed, pointSize: pointSize)
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func drawSpeedText(_ speed: SpeedLayout, pointSize: NSSize) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byTruncatingHead
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: MenuBarLayoutTokens.FontSize.statusBar, weight: .semibold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]

        let stackHeight = self.textLineHeight * 2
        let stackOriginY = floor((pointSize.height - stackHeight) / 2)
        let upRect = CGRect(
            x: speed.originX,
            y: stackOriginY + self.textLineHeight,
            width: self.textContainerWidth,
            height: self.textLineHeight)
        let downRect = CGRect(
            x: speed.originX,
            y: stackOriginY,
            width: self.textContainerWidth,
            height: self.textLineHeight)

        (speed.up as NSString).draw(in: upRect, withAttributes: attributes)
        (speed.down as NSString).draw(in: downRect, withAttributes: attributes)
    }

    private static func aspectFitRect(imageSize: NSSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(
            x: bounds.minX + (bounds.width - width) / 2,
            y: bounds.minY + (bounds.height - height) / 2,
            width: width,
            height: height)
    }

    private static func makeBrandStatusIconImage(source: NSImage?, size: CGFloat) -> NSImage? {
        guard let source else { return nil }
        let targetSize = NSSize(width: size, height: size)
        let rendered = NSImage(size: targetSize)

        for scale in Self.renderScales {
            guard let representation = self.makeBrandStatusIconRepresentation(
                source: source,
                pointSize: targetSize,
                scale: scale)
            else { continue }
            rendered.addRepresentation(representation)
        }

        guard rendered.representations.isEmpty == false else { return nil }
        rendered.isTemplate = true
        return rendered
    }

    private static func makeBrandStatusIconRepresentation(
        source: NSImage,
        pointSize: NSSize,
        scale: CGFloat) -> NSBitmapImageRep?
    {
        let pixelWidth = max(1, Int((pointSize.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((pointSize.height * scale).rounded(.up)))

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        else { return nil }

        representation.size = pointSize

        guard let context = NSGraphicsContext(bitmapImageRep: representation) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: pointSize),
            from: .zero,
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: nil)
        context.cgContext.setBlendMode(.sourceIn)
        context.cgContext.setFillColor(NSColor.black.cgColor)
        context.cgContext.fill(CGRect(origin: .zero, size: pointSize))
        NSGraphicsContext.restoreGraphicsState()
        return representation
    }
}
