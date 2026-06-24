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
    static let statusSignalPath = "/tmp/corgiwalker-status"

    let initialBreed: DogBreed
    let canvasWidth: CGFloat
    let speed: CGFloat
    let startsWithPortalVisible: Bool
    let startsWithHouseVisible: Bool

    static func from(arguments: [String]) -> AppConfiguration {
        AppConfiguration(
            initialBreed: breedArgument(in: arguments),
            canvasWidth: widthArgument(in: arguments),
            speed: speedArgument(in: arguments),
            startsWithPortalVisible: flagPresent("--portal", in: arguments),
            startsWithHouseVisible: flagPresent("--house", in: arguments)
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

    private static func flagPresent(_ flag: String, in arguments: [String]) -> Bool {
        arguments.contains(flag)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let animation: DogAnimationController
    private var currentBreed: DogBreed
    private var currentWidth: CGFloat
    private var currentSpeed: CGFloat
    private var showsTrack = false
    private var showsPortal = false
    private var showsHouse = false
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var breedMenuItems: [DogBreed: NSMenuItem] = [:]
    private var trackMenuItem: NSMenuItem?
    private var portalMenuItem: NSMenuItem?
    private var houseMenuItem: NSMenuItem?

    override init() {
        let configuration = AppConfiguration.from(arguments: CommandLine.arguments)
        currentBreed = configuration.initialBreed
        currentWidth = configuration.canvasWidth
        currentSpeed = configuration.speed
        showsPortal = configuration.startsWithPortalVisible
        showsHouse = configuration.startsWithHouseVisible
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
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

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

        let trackItem = NSMenuItem(
            title: "Show Track",
            action: #selector(toggleTrack),
            keyEquivalent: ""
        )
        trackItem.target = self
        trackItem.state = .off
        trackMenuItem = trackItem
        menu.addItem(trackItem)

        menu.addItem(NSMenuItem.separator())

        let portalItem = NSMenuItem(
            title: "Portal",
            action: #selector(togglePortal),
            keyEquivalent: ""
        )
        portalItem.target = self
        portalItem.state = .off
        portalMenuItem = portalItem
        menu.addItem(portalItem)

        menu.addItem(NSMenuItem.separator())

        let houseItem = NSMenuItem(
            title: "House",
            action: #selector(toggleHouse),
            keyEquivalent: ""
        )
        houseItem.target = self
        houseItem.state = .off
        houseMenuItem = houseItem
        menu.addItem(houseItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Corgi Walker",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusMenu = menu
        statusItem = item

        applyBreed(currentBreed)
        applyWidth(currentWidth)
        applySpeed(currentSpeed)
        applyTrackVisibility(showsTrack)
        applyPortalVisibility(showsPortal)
        applyHouseVisibility(showsHouse)
        animation.start(on: button, canvasWidth: currentWidth)
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }

        if shouldOpenMenu(for: event) {
            statusMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY - 2), in: sender)
            return
        }

        let clickPoint = sender.convert(event.locationInWindow, from: nil)
        animation.handleClick(at: clickPoint)
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

    @objc
    private func toggleTrack() {
        applyTrackVisibility(!showsTrack)
    }

    private func applyTrackVisibility(_ showsTrack: Bool) {
        self.showsTrack = showsTrack
        trackMenuItem?.state = showsTrack ? .on : .off
        animation.setTrackVisible(showsTrack)
    }

    @objc
    private func togglePortal() {
        applyPortalVisibility(!showsPortal)
    }

    private func applyPortalVisibility(_ showsPortal: Bool) {
        self.showsPortal = showsPortal
        portalMenuItem?.state = showsPortal ? .on : .off
        animation.setPortalVisible(showsPortal)
    }

    @objc
    private func toggleHouse() {
        applyHouseVisibility(!showsHouse)
    }

    private func applyHouseVisibility(_ showsHouse: Bool) {
        self.showsHouse = showsHouse
        houseMenuItem?.state = showsHouse ? .on : .off
        animation.setHouseVisible(showsHouse)
    }

    private func shouldOpenMenu(for event: NSEvent) -> Bool {
        if event.type == .rightMouseUp {
            return true
        }

        return event.type == .leftMouseUp && event.modifierFlags.contains(.control)
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
    private struct PortalZone {
        let leftPortalX: CGFloat
        let rightPortalX: CGFloat
    }

    private weak var button: NSStatusBarButton?
    private var timer: Timer?
    private var direction: CGFloat = 1
    private var position: CGFloat = 6
    private var canvasWidth: CGFloat = 72
    private var breed: DogBreed
    private var speed: CGFloat
    private var showsTrack = false
    private var showsPortal = false
    private var showsHouse = false
    private var isPausedBySignal = false
    private var showsPauseAlert = false
    private var targetPosition: CGFloat?
    private var spinAngle: CGFloat = 0
    private var spinStepCount = 0
    private var sleepStepCount = 0
    private var hasCheckedHouseOnCurrentApproach = false
    private var signalPollStepCount = 0
    private var lastSignalContents = ""

    private let canvasHeight: CGFloat = 18
    private let spinFrameCount = 10
    private let houseSize = CGSize(width: 14, height: 13)
    private let signalPollInterval = 8

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

    func setTrackVisible(_ showsTrack: Bool) {
        self.showsTrack = showsTrack
        redraw()
    }

    func setPortalVisible(_ showsPortal: Bool) {
        self.showsPortal = showsPortal
        targetPosition = adjustedTargetPosition(targetPosition)
        clampPosition()
        redraw()
    }

    func setHouseVisible(_ showsHouse: Bool) {
        self.showsHouse = showsHouse
        sleepStepCount = 0
        hasCheckedHouseOnCurrentApproach = false
        redraw()
    }

    func handleClick(at point: CGPoint) {
        if sleepStepCount > 0, showsHouse, houseBounds.contains(point) {
            startSpin()
            redraw()
            return
        }

        if dogBounds.contains(point) {
            startSpin()
            redraw()
            return
        }

        guard let target = adjustedTargetPosition(point.x) else {
            return
        }

        direction = target >= position ? 1 : -1
        targetPosition = target
        redraw()
    }

    @objc
    private func step() {
        pollSignalIfNeeded()

        if spinStepCount > 0 {
            spinStepCount -= 1
            spinAngle += 36

            if spinStepCount == 0 {
                spinAngle = 0
            }

            redraw()
            return
        }

        if isPausedBySignal {
            redraw()
            return
        }

        if sleepStepCount > 0 {
            sleepStepCount -= 1

            if sleepStepCount == 0 {
                direction = -1
            }

            redraw()
            return
        }

        position += direction * speed
        applyPortalTransitionIfNeeded()
        applyTargetPositionIfNeeded()
        applyHouseBehaviorIfNeeded()

        if position <= 6 {
            position = 6
            direction = 1
            hasCheckedHouseOnCurrentApproach = false
        } else if position >= maxPositionX {
            position = maxPositionX
            direction = -1
        }

        redraw()
    }

    private func pollSignalIfNeeded() {
        signalPollStepCount += 1

        guard signalPollStepCount >= signalPollInterval else {
            return
        }

        signalPollStepCount = 0

        guard
            let contents = try? String(contentsOfFile: AppConfiguration.statusSignalPath, encoding: .utf8)
        else {
            if !lastSignalContents.isEmpty {
                lastSignalContents = ""
            }
            return
        }

        let normalizedContents = contents
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard normalizedContents != lastSignalContents else {
            return
        }

        lastSignalContents = normalizedContents

        switch normalizedContents {
        case "pause":
            isPausedBySignal = true
            showsPauseAlert = true
        case "stop", "busy":
            isPausedBySignal = true
            showsPauseAlert = false
        case "resume", "go", "idle":
            isPausedBySignal = false
            showsPauseAlert = false
        default:
            break
        }
    }

    private var maxPositionX: CGFloat {
        canvasWidth - breed.spriteSize.width - 6
    }

    private var dogBounds: NSRect {
        NSRect(x: position, y: 2, width: breed.spriteSize.width, height: breed.spriteSize.height)
    }

    private var isSleeping: Bool {
        sleepStepCount > 0
    }

    private var shouldDrawDogWhilePaused: Bool {
        isPausedBySignal && showsPauseAlert
    }

    private var houseBounds: NSRect {
        NSRect(
            x: canvasWidth - houseSize.width - 4,
            y: 2,
            width: houseSize.width,
            height: houseSize.height
        )
    }

    private func clampPosition() {
        position = min(max(position, 6), maxPositionX)
        targetPosition = adjustedTargetPosition(targetPosition)
        applyPortalTransitionIfNeeded()
        applyTargetPositionIfNeeded()
        resetHouseApproachIfNeeded()
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

        if showsTrack {
            let trackRect = NSRect(
                x: 4,
                y: 6.5,
                width: canvasWidth - 8,
                height: 5
            )
            let track = NSBezierPath(roundedRect: trackRect, xRadius: 2.5, yRadius: 2.5)
            NSColor(white: 0.75, alpha: 0.25).setFill()
            track.fill()
        }

        if showsPortal, let portalZone = currentPortalZone() {
            drawPortal(portalZone)
        }

        if showsHouse {
            drawHouse()
        }

        if !isSleeping || shouldDrawDogWhilePaused {
            let origin = CGPoint(x: position, y: 2)
            let facingRight = direction > 0
            let pauseTint = currentPauseTintColor()

            switch breed {
            case .corgi:
                drawCorgi(at: origin, facingRight: facingRight, pauseTint: pauseTint)
            case .papillon:
                drawPapillon(at: origin, facingRight: facingRight, pauseTint: pauseTint)
            }
        }
    }

    private func currentPauseTintColor() -> NSColor? {
        guard showsPauseAlert, isPausedBySignal else {
            return nil
        }

        let blinkPhase = (signalPollStepCount / 2) % 2
        guard blinkPhase == 0 else {
            return nil
        }

        return NSColor(calibratedRed: 0.95, green: 0.16, blue: 0.12, alpha: 0.72)
    }

    private func currentPortalZone() -> PortalZone? {
        let travelWidth = maxPositionX - 6

        guard travelWidth > 0 else {
            return nil
        }

        let leftPortalX = 6 + (travelWidth * 0.35)
        let rightPortalX = 6 + (travelWidth * 0.65)

        guard rightPortalX > leftPortalX else {
            return nil
        }

        return PortalZone(
            leftPortalX: leftPortalX,
            rightPortalX: rightPortalX
        )
    }

    private func applyPortalTransitionIfNeeded() {
        guard showsPortal, let portalZone = currentPortalZone() else {
            return
        }

        if direction > 0, position >= portalZone.leftPortalX, position < portalZone.rightPortalX {
            position = portalZone.rightPortalX
        } else if direction < 0, position <= portalZone.rightPortalX, position > portalZone.leftPortalX {
            position = portalZone.leftPortalX
        }
    }

    private func applyTargetPositionIfNeeded() {
        guard let targetPosition else {
            return
        }

        let reachedTarget = direction > 0 ? position >= targetPosition : position <= targetPosition

        if reachedTarget {
            position = targetPosition
            self.targetPosition = nil
        }
    }

    private func adjustedTargetPosition(_ rawTargetPosition: CGFloat?) -> CGFloat? {
        guard let rawTargetPosition else {
            return nil
        }

        let upperBound = showsHouse ? houseRestPosition : maxPositionX
        let clampedTarget = min(max(rawTargetPosition, 6), upperBound)

        guard showsPortal, let portalZone = currentPortalZone() else {
            return clampedTarget
        }

        if clampedTarget > portalZone.leftPortalX && clampedTarget < portalZone.rightPortalX {
            let portalMidpoint = (portalZone.leftPortalX + portalZone.rightPortalX) / 2
            return clampedTarget < portalMidpoint ? portalZone.leftPortalX : portalZone.rightPortalX
        }

        return clampedTarget
    }

    private func startSpin() {
        if sleepStepCount > 0 {
            direction = -1
            hasCheckedHouseOnCurrentApproach = true
        }

        spinStepCount = spinFrameCount
        spinAngle = 0
        sleepStepCount = 0
        targetPosition = nil
    }

    private var houseRestPosition: CGFloat {
        min(maxPositionX, houseBounds.minX - (breed.spriteSize.width * 0.2))
    }

    private func applyHouseBehaviorIfNeeded() {
        guard showsHouse else { return }

        if direction < 0 || position < houseRestPosition {
            hasCheckedHouseOnCurrentApproach = false
            return
        }

        guard !hasCheckedHouseOnCurrentApproach else { return }
        guard position >= houseRestPosition else { return }

        hasCheckedHouseOnCurrentApproach = true
        position = houseRestPosition

        if Int.random(in: 1...3) == 1 {
            sleepStepCount = Int.random(in: 167...500)
            targetPosition = nil
            spinStepCount = 0
            spinAngle = 0
            return
        }

        direction = -1
    }

    private func resetHouseApproachIfNeeded() {
        if direction < 0 || position < houseRestPosition {
            hasCheckedHouseOnCurrentApproach = false
        }
    }

    private func drawPortal(_ portalZone: PortalZone) {
        drawPortalOval(
            centerX: portalZone.leftPortalX + (breed.spriteSize.width / 2),
            color: NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.12, alpha: 0.85)
        )
        drawPortalOval(
            centerX: portalZone.rightPortalX + (breed.spriteSize.width / 2),
            color: NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.96, alpha: 0.85)
        )
    }

    private func drawPortalOval(centerX: CGFloat, color: NSColor) {
        let ovalRect = NSRect(x: centerX - 4, y: 3.5, width: 8, height: 11)
        let ovalPath = NSBezierPath(ovalIn: ovalRect)
        color.setFill()
        ovalPath.fill()

        ovalPath.lineWidth = 1
        NSColor(calibratedWhite: 1, alpha: 0.55).setStroke()
        ovalPath.stroke()
    }

    private func drawHouse() {
        let roofPath = NSBezierPath()
        roofPath.move(to: CGPoint(x: houseBounds.minX, y: houseBounds.minY + 6))
        roofPath.line(to: CGPoint(x: houseBounds.midX, y: houseBounds.maxY))
        roofPath.line(to: CGPoint(x: houseBounds.maxX, y: houseBounds.minY + 6))
        roofPath.close()
        NSColor(calibratedRed: 0.66, green: 0.24, blue: 0.16, alpha: 1).setFill()
        roofPath.fill()

        let bodyRect = NSRect(x: houseBounds.minX + 1.5, y: houseBounds.minY, width: houseBounds.width - 3, height: 7.5)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 1.4, yRadius: 1.4)
        NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.46, alpha: 1).setFill()
        bodyPath.fill()

        let doorRect = NSRect(x: houseBounds.midX - 1.9, y: houseBounds.minY, width: 3.8, height: 5.8)
        let doorPath = NSBezierPath(roundedRect: doorRect, xRadius: 1, yRadius: 1)
        NSColor(calibratedRed: 0.36, green: 0.18, blue: 0.11, alpha: 1).setFill()
        doorPath.fill()

        let outlinePath = NSBezierPath()
        outlinePath.append(roofPath)
        outlinePath.append(bodyPath)
        outlinePath.lineWidth = 0.8
        NSColor(calibratedWhite: 0.08, alpha: 0.45).setStroke()
        outlinePath.stroke()

        if isSleeping {
            drawSleepIndicators()
        }
    }

    private func drawSleepIndicators() {
        let cycle = sleepStepCount % 24
        let baseX = houseBounds.maxX - 1
        let firstOffset = CGFloat(cycle % 4)
        let secondOffset = CGFloat((cycle + 8) % 4)
        let thirdOffset = CGFloat((cycle + 16) % 4)

        drawSleepGlyph(
            text: "Z",
            x: baseX + firstOffset,
            y: 10 + (firstOffset * 0.4),
            fontSize: 7,
            alpha: 0.95
        )
        drawSleepGlyph(
            text: "Z",
            x: baseX + 3 + secondOffset,
            y: 12.5 + (secondOffset * 0.35),
            fontSize: 6,
            alpha: 0.78
        )
        drawSleepGlyph(
            text: "z",
            x: baseX + 6 + thirdOffset,
            y: 14.2 + (thirdOffset * 0.25),
            fontSize: 5,
            alpha: 0.62
        )
    }

    private func drawSleepGlyph(
        text: String,
        x: CGFloat,
        y: CGFloat,
        fontSize: CGFloat,
        alpha: CGFloat
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: alpha)
        ]
        NSString(string: text).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
    }

    private func drawCorgi(at origin: CGPoint, facingRight: Bool, pauseTint: NSColor?) {
        let transform = drawingTransform(origin: origin, facingRight: facingRight)

        fillRoundedRect(
            x: 4,
            y: 3,
            width: 13,
            height: 7,
            radius: 3,
            color: tintedColor(
                NSColor(calibratedRed: 0.86, green: 0.52, blue: 0.22, alpha: 1),
                pauseTint: pauseTint
            ),
            transform: transform
        )

        fillRoundedRect(
            x: 13,
            y: 5,
            width: 7,
            height: 6,
            radius: 3,
            color: tintedColor(
                NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.58, alpha: 1),
                pauseTint: pauseTint
            ),
            transform: transform
        )

        fillRoundedRect(
            x: 5,
            y: 2,
            width: 9,
            height: 3.5,
            radius: 1.75,
            color: tintedColor(.white, pauseTint: pauseTint),
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

        drawEar(x: 14.2, y: 9.5, width: 3.2, height: 3.2, color: tintedColor(NSColor(calibratedRed: 0.78, green: 0.42, blue: 0.14, alpha: 1), pauseTint: pauseTint), transform: transform)
        drawEar(x: 17.7, y: 9.4, width: 3.2, height: 3.1, color: tintedColor(NSColor(calibratedRed: 0.78, green: 0.42, blue: 0.14, alpha: 1), pauseTint: pauseTint), transform: transform)
        drawLeg(x: 6.1, y: 0.4, height: 3.5, color: tintedColor(.white, pauseTint: pauseTint), transform: transform)
        drawLeg(x: 9.4, y: 0.4, height: 3.5, color: tintedColor(.white, pauseTint: pauseTint), transform: transform)
        drawLeg(x: 13, y: 0.4, height: 3.5, color: tintedColor(.white, pauseTint: pauseTint), transform: transform)
        drawLeg(x: 15.8, y: 0.4, height: 3.5, color: tintedColor(.white, pauseTint: pauseTint), transform: transform)
        drawTail(
            start: CGPoint(x: 3.5, y: 8.2),
            end: CGPoint(x: 0.6, y: 10.5),
            controlPoint1: CGPoint(x: 2.2, y: 10),
            controlPoint2: CGPoint(x: 1.4, y: 10.6),
            width: 1.7,
            color: tintedColor(
                NSColor(calibratedRed: 0.86, green: 0.52, blue: 0.22, alpha: 1),
                pauseTint: pauseTint
            ),
            transform: transform
        )
        drawOutline(
            bodyRect: NSRect(x: 4, y: 3, width: 13, height: 7),
            headRect: NSRect(x: 13, y: 5, width: 7, height: 6),
            transform: transform
        )
    }

    private func drawPapillon(at origin: CGPoint, facingRight: Bool, pauseTint: NSColor?) {
        let transform = drawingTransform(origin: origin, facingRight: facingRight)
        let coatColor = tintedColor(
            NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.92, alpha: 1),
            pauseTint: pauseTint
        )
        let accentColor = tintedColor(
            NSColor(calibratedRed: 0.72, green: 0.36, blue: 0.16, alpha: 1),
            pauseTint: pauseTint
        )

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
            color: tintedColor(.black, pauseTint: pauseTint),
            transform: transform
        )

        fillRoundedRect(
            x: 18.3,
            y: 5.1,
            width: 1.5,
            height: 1.5,
            radius: 0.75,
            color: tintedColor(.black, pauseTint: pauseTint),
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

        if spinAngle > 0 {
            transform.translate(x: breed.spriteSize.width / 2, y: breed.spriteSize.height / 2)
            transform.rotate(byDegrees: spinAngle)
            transform.translate(x: -(breed.spriteSize.width / 2), y: -(breed.spriteSize.height / 2))
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

    private func tintedColor(_ baseColor: NSColor, pauseTint: NSColor?) -> NSColor {
        guard let pauseTint else {
            return baseColor
        }

        return baseColor.blended(withFraction: 0.72, of: pauseTint) ?? pauseTint
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
