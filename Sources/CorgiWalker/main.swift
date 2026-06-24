import AppKit

enum DogBreed: String, CaseIterable {
    case corgi
    case papillon

    var displayName: String {
        switch self {
        case .corgi:
            return "Corgi"
        case .papillon:
            return "Papillon"
        }
    }

    var spriteSize: CGSize {
        switch self {
        case .corgi:
            return CGSize(width: 22, height: 14)
        case .papillon:
            return CGSize(width: 24, height: 15)
        }
    }

    var tooltip: String {
        "\(displayName) Walker"
    }
}

struct AppConfiguration {
    static let defaultCanvasWidth: CGFloat = 72
    static let minimumCanvasWidth: CGFloat = 40
    static let defaultSpeed: CGFloat = 1.15
    static let minimumSpeed: CGFloat = 0.1

    let initialBreed: DogBreed
    let canvasWidth: CGFloat
    let speed: CGFloat

    static func from(arguments: [String]) -> AppConfiguration {
        AppConfiguration(
            initialBreed: breedArgument(in: arguments),
            canvasWidth: widthArgument(in: arguments),
            speed: speedArgument(in: arguments)
        )
    }

    private static func breedArgument(in arguments: [String]) -> DogBreed {
        value(for: "--dog", in: arguments)
            .flatMap { DogBreed(rawValue: $0.lowercased()) } ?? .corgi
    }

    private static func widthArgument(in arguments: [String]) -> CGFloat {
        guard
            let widthValue = value(for: "--width", in: arguments),
            let width = Double(widthValue)
        else {
            return defaultCanvasWidth
        }

        return max(CGFloat(width), minimumCanvasWidth)
    }

    private static func speedArgument(in arguments: [String]) -> CGFloat {
        guard
            let speedValue = value(for: "--speed", in: arguments),
            let speed = Double(speedValue)
        else {
            return defaultSpeed
        }

        return max(CGFloat(speed), minimumSpeed)
    }

    private static func value(for flag: String, in arguments: [String]) -> String? {
        guard let flagIndex = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return arguments[valueIndex]
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let animation: DogAnimationController
    private var currentBreed: DogBreed
    private var currentWidth: CGFloat
    private var currentSpeed: CGFloat
    private var statusItem: NSStatusItem?
    private var breedMenuItems: [DogBreed: NSMenuItem] = [:]

    override init() {
        let configuration = AppConfiguration.from(arguments: CommandLine.arguments)
        currentBreed = configuration.initialBreed
        currentWidth = configuration.canvasWidth
        currentSpeed = configuration.speed
        animation = DogAnimationController(
            breed: configuration.initialBreed,
            speed: configuration.speed
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: currentWidth)

        guard let button = item.button else {
            NSApp.terminate(nil)
            return
        }

        button.imagePosition = .imageOnly

        let menu = NSMenu()

        for breed in DogBreed.allCases {
            let item = NSMenuItem(
                title: "Show \(breed.displayName)",
                action: #selector(selectBreed(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = breed.rawValue
            breedMenuItems[breed] = item
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let widthItem = NSMenuItem(
            title: "Set Width...",
            action: #selector(promptForWidth),
            keyEquivalent: ""
        )
        widthItem.target = self
        menu.addItem(widthItem)

        menu.addItem(NSMenuItem.separator())

        let speedItem = NSMenuItem(
            title: "Set Speed...",
            action: #selector(promptForSpeed),
            keyEquivalent: ""
        )
        speedItem.target = self
        menu.addItem(speedItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Corgi Walker",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item

        applyBreed(currentBreed)
        applyWidth(currentWidth)
        applySpeed(currentSpeed)
        animation.start(on: button, canvasWidth: currentWidth)
    }

    @objc
    private func selectBreed(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let breed = DogBreed(rawValue: rawValue)
        else {
            return
        }

        applyBreed(breed)
    }

    private func applyBreed(_ breed: DogBreed) {
        currentBreed = breed
        statusItem?.button?.toolTip = breed.tooltip
        animation.setBreed(breed)

        for option in DogBreed.allCases {
            breedMenuItems[option]?.state = option == breed ? .on : .off
        }
    }

    @objc
    private func promptForWidth() {
        guard let width = promptForNumber(
            title: "Set Width",
            message: "Enter the menu bar slot width. Minimum \(Int(AppConfiguration.minimumCanvasWidth)).",
            currentValue: currentWidth,
            minimumValue: AppConfiguration.minimumCanvasWidth
        ) else {
            return
        }

        applyWidth(width)
    }

    @objc
    private func promptForSpeed() {
        guard let speed = promptForNumber(
            title: "Set Speed",
            message: "Enter the movement speed. Minimum \(formatNumber(AppConfiguration.minimumSpeed)).",
            currentValue: currentSpeed,
            minimumValue: AppConfiguration.minimumSpeed
        ) else {
            return
        }

        applySpeed(speed)
    }

    private func applyWidth(_ width: CGFloat) {
        currentWidth = width
        statusItem?.length = width
        animation.setCanvasWidth(width)
    }

    private func applySpeed(_ speed: CGFloat) {
        currentSpeed = speed
        animation.setSpeed(speed)
    }

    private func promptForNumber(
        title: String,
        message: String,
        currentValue: CGFloat,
        minimumValue: CGFloat
    ) -> CGFloat? {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        inputField.stringValue = formatNumber(currentValue)
        alert.accessoryView = inputField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }

        let rawValue = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedValue = Double(rawValue) else {
            NSSound.beep()
            return nil
        }

        return max(CGFloat(parsedValue), minimumValue)
    }

    private func formatNumber(_ value: CGFloat) -> String {
        let roundedValue = value.rounded(.towardZero)

        if abs(value - roundedValue) < 0.0001 {
            return String(Int(roundedValue))
        }

        return String(format: "%.2f", value)
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}

final class DogAnimationController {
    private weak var button: NSStatusBarButton?
    private var timer: Timer?
    private var direction: CGFloat = 1
    private var position: CGFloat = 6
    private var canvasWidth: CGFloat = 72
    private var breed: DogBreed
    private var speed: CGFloat

    private let canvasHeight: CGFloat = 18

    init(breed: DogBreed, speed: CGFloat) {
        self.breed = breed
        self.speed = speed
    }

    func start(on button: NSStatusBarButton, canvasWidth: CGFloat) {
        self.button = button
        self.canvasWidth = canvasWidth
        clampPosition()
        redraw()

        timer = Timer.scheduledTimer(
            timeInterval: 0.06,
            target: self,
            selector: #selector(step),
            userInfo: nil,
            repeats: true
        )
    }

    func setBreed(_ breed: DogBreed) {
        self.breed = breed
        clampPosition()
        redraw()
    }

    func setCanvasWidth(_ canvasWidth: CGFloat) {
        self.canvasWidth = canvasWidth
        clampPosition()
        redraw()
    }

    func setSpeed(_ speed: CGFloat) {
        self.speed = speed
    }

    @objc
    private func step() {
        position += direction * speed

        if position <= 6 {
            position = 6
            direction = 1
        } else if position >= maxPositionX {
            position = maxPositionX
            direction = -1
        }

        redraw()
    }

    private var maxPositionX: CGFloat {
        canvasWidth - breed.spriteSize.width - 6
    }

    private func clampPosition() {
        position = min(max(position, 6), maxPositionX)
    }

    private func redraw() {
        guard let button else { return }

        let image = NSImage(
            size: CGSize(width: canvasWidth, height: canvasHeight),
            flipped: false
        ) { [self] rect in
            drawScene(in: rect)
            return true
        }

        image.isTemplate = false
        button.image = image
    }

    private func drawScene(in rect: NSRect) {
        NSColor.clear.setFill()
        rect.fill()

        let trackRect = NSRect(
            x: 4,
            y: 6.5,
            width: canvasWidth - 8,
            height: 5
        )
        let track = NSBezierPath(roundedRect: trackRect, xRadius: 2.5, yRadius: 2.5)
        NSColor(white: 0.75, alpha: 0.25).setFill()
        track.fill()

        let origin = CGPoint(x: position, y: 2)
        let facingRight = direction > 0

        switch breed {
        case .corgi:
            drawCorgi(at: origin, facingRight: facingRight)
        case .papillon:
            drawPapillon(at: origin, facingRight: facingRight)
        }
    }

    private func drawCorgi(at origin: CGPoint, facingRight: Bool) {
        let transform = drawingTransform(origin: origin, facingRight: facingRight)

        fillRoundedRect(
            x: 4,
            y: 3,
            width: 13,
            height: 7,
            radius: 3,
            color: NSColor(calibratedRed: 0.86, green: 0.52, blue: 0.22, alpha: 1),
            transform: transform
        )

        fillRoundedRect(
            x: 13,
            y: 5,
            width: 7,
            height: 6,
            radius: 3,
            color: NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.58, alpha: 1),
            transform: transform
        )

        fillRoundedRect(
            x: 5,
            y: 2,
            width: 9,
            height: 3.5,
            radius: 1.75,
            color: .white,
            transform: transform
        )

        fillRoundedRect(
            x: 16.3,
            y: 5.4,
            width: 2.2,
            height: 2.2,
            radius: 1.1,
            color: .black,
            transform: transform
        )

        fillRoundedRect(
            x: 18.2,
            y: 4.1,
            width: 1.7,
            height: 1.7,
            radius: 0.85,
            color: .black,
            transform: transform
        )

        drawEar(x: 14.2, y: 9.5, width: 3.2, height: 3.2, color: NSColor(calibratedRed: 0.78, green: 0.42, blue: 0.14, alpha: 1), transform: transform)
        drawEar(x: 17.7, y: 9.4, width: 3.2, height: 3.1, color: NSColor(calibratedRed: 0.78, green: 0.42, blue: 0.14, alpha: 1), transform: transform)
        drawLeg(x: 6.1, y: 0.4, height: 3.5, color: .white, transform: transform)
        drawLeg(x: 9.4, y: 0.4, height: 3.5, color: .white, transform: transform)
        drawLeg(x: 13, y: 0.4, height: 3.5, color: .white, transform: transform)
        drawLeg(x: 15.8, y: 0.4, height: 3.5, color: .white, transform: transform)
        drawTail(
            start: CGPoint(x: 3.5, y: 8.2),
            end: CGPoint(x: 0.6, y: 10.5),
            controlPoint1: CGPoint(x: 2.2, y: 10),
            controlPoint2: CGPoint(x: 1.4, y: 10.6),
            width: 1.7,
            color: NSColor(calibratedRed: 0.86, green: 0.52, blue: 0.22, alpha: 1),
            transform: transform
        )
        drawOutline(
            bodyRect: NSRect(x: 4, y: 3, width: 13, height: 7),
            headRect: NSRect(x: 13, y: 5, width: 7, height: 6),
            transform: transform
        )
    }

    private func drawPapillon(at origin: CGPoint, facingRight: Bool) {
        let transform = drawingTransform(origin: origin, facingRight: facingRight)
        let coatColor = NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.92, alpha: 1)
        let accentColor = NSColor(calibratedRed: 0.72, green: 0.36, blue: 0.16, alpha: 1)

        fillRoundedRect(
            x: 5,
            y: 3.3,
            width: 12.5,
            height: 6.2,
            radius: 3.1,
            color: coatColor,
            transform: transform
        )

        fillRoundedRect(
            x: 14.2,
            y: 5,
            width: 6.2,
            height: 5.5,
            radius: 2.8,
            color: coatColor,
            transform: transform
        )

        fillRoundedRect(
            x: 15.6,
            y: 5.2,
            width: 2.1,
            height: 4.9,
            radius: 1,
            color: accentColor,
            transform: transform
        )

        fillRoundedRect(
            x: 7.2,
            y: 2.2,
            width: 8.7,
            height: 2.8,
            radius: 1.4,
            color: accentColor,
            transform: transform
        )

        fillRoundedRect(
            x: 16.5,
            y: 6.5,
            width: 1.7,
            height: 1.7,
            radius: 0.85,
            color: .black,
            transform: transform
        )

        fillRoundedRect(
            x: 18.3,
            y: 5.1,
            width: 1.5,
            height: 1.5,
            radius: 0.75,
            color: .black,
            transform: transform
        )

        drawEar(x: 13.4, y: 8.6, width: 4.8, height: 5.7, color: accentColor, transform: transform)
        drawEar(x: 16.6, y: 8.4, width: 5.1, height: 5.9, color: accentColor, transform: transform)
        drawLeg(x: 7.3, y: 0.2, height: 4.2, color: coatColor, transform: transform)
        drawLeg(x: 10.5, y: 0.1, height: 4.3, color: coatColor, transform: transform)
        drawLeg(x: 13.7, y: 0.2, height: 4.2, color: coatColor, transform: transform)
        drawLeg(x: 16.1, y: 0.1, height: 4.1, color: coatColor, transform: transform)
        drawTail(
            start: CGPoint(x: 6, y: 8.7),
            end: CGPoint(x: 1, y: 13),
            controlPoint1: CGPoint(x: 3.8, y: 11.8),
            controlPoint2: CGPoint(x: 2.1, y: 13.1),
            width: 2,
            color: coatColor,
            transform: transform
        )
        drawOutline(
            bodyRect: NSRect(x: 5, y: 3.3, width: 12.5, height: 6.2),
            headRect: NSRect(x: 14.2, y: 5, width: 6.2, height: 5.5),
            transform: transform
        )
    }

    private func drawingTransform(origin: CGPoint, facingRight: Bool) -> AffineTransform {
        var transform = AffineTransform()
        transform.translate(x: origin.x, y: origin.y)

        if !facingRight {
            transform.translate(x: breed.spriteSize.width, y: 0)
            transform.scale(x: -1, y: 1)
        }

        return transform
    }

    private func fillRoundedRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat,
        color: NSColor,
        transform: AffineTransform
    ) {
        let path = NSBezierPath(
            roundedRect: NSRect(x: x, y: y, width: width, height: height),
            xRadius: radius,
            yRadius: radius
        )
        path.transform(using: transform)
        color.setFill()
        path.fill()
    }

    private func drawEar(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        color: NSColor,
        transform: AffineTransform
    ) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.line(to: CGPoint(x: x + (width * 0.55), y: y + height))
        path.line(to: CGPoint(x: x + width, y: y + (height * 0.2)))
        path.close()
        path.transform(using: transform)
        color.setFill()
        path.fill()
    }

    private func drawLeg(
        x: CGFloat,
        y: CGFloat,
        height: CGFloat,
        color: NSColor,
        transform: AffineTransform
    ) {
        let path = NSBezierPath(
            roundedRect: NSRect(x: x, y: y, width: 1.6, height: height),
            xRadius: 0.8,
            yRadius: 0.8
        )
        path.transform(using: transform)
        color.setFill()
        path.fill()
    }

    private func drawTail(
        start: CGPoint,
        end: CGPoint,
        controlPoint1: CGPoint,
        controlPoint2: CGPoint,
        width: CGFloat,
        color: NSColor,
        transform: AffineTransform
    ) {
        let path = NSBezierPath()
        path.move(to: start)
        path.curve(
            to: end,
            controlPoint1: controlPoint1,
            controlPoint2: controlPoint2
        )
        path.lineWidth = width
        path.lineCapStyle = .round
        path.transform(using: transform)
        color.setStroke()
        path.stroke()
    }

    private func drawOutline(
        bodyRect: NSRect,
        headRect: NSRect,
        transform: AffineTransform
    ) {
        let outline = NSBezierPath(
            roundedRect: bodyRect,
            xRadius: 3,
            yRadius: 3
        )
        outline.appendRoundedRect(headRect, xRadius: 3, yRadius: 3)
        outline.transform(using: transform)
        outline.lineWidth = 0.7
        NSColor(calibratedWhite: 0.1, alpha: 0.6).setStroke()
        outline.stroke()
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()

application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
