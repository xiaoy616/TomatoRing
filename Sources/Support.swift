import AppKit
import SwiftUI

/// 菜单栏圆环图标：轨道 + 按进度填充的弧线。
enum RingImage {
    static let size: CGFloat = 20
    static let lineWidth: CGFloat = 3.0

    static func make(progress: Double, color: NSColor, trackColor: NSColor? = nil, size: CGFloat = RingImage.size, lineWidth: CGFloat = RingImage.lineWidth) -> NSImage {
        let canvas = NSSize(width: size, height: size)
        let image = NSImage(size: canvas, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2 - 2.0

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            (trackColor ?? NSColor.labelColor.withAlphaComponent(0.20)).setStroke()
            track.stroke()

            let clamped = min(max(progress, 0), 1)
            if clamped > 0.002 {
                let arc = NSBezierPath()
                arc.appendArc(
                    withCenter: center,
                    radius: radius,
                    startAngle: 90,
                    endAngle: 90 - 360 * CGFloat(clamped),
                    clockwise: true
                )
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                color.setStroke()
                arc.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// 空闲态：一整圈实心绿环
    static func idle(size: CGFloat = RingImage.size) -> NSImage {
        make(progress: 1, color: .ringGreen, size: size)
    }
}

func formatDuration(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded(.up)))
    if total >= 3600 {
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
    return String(format: "%02d:%02d", total / 60, total % 60)
}

func formatMinutes(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes) 分钟" }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "\(hours) 小时" : "\(hours) 小时 \(rest) 分钟"
}

extension NSColor {
    /// 主色：绿
    static let ringGreen = NSColor(calibratedRed: 0.16, green: 0.74, blue: 0.44, alpha: 1)
    /// 休息时的浅绿
    static let ringMint = NSColor(calibratedRed: 0.36, green: 0.84, blue: 0.58, alpha: 1)
    /// 休息：蓝
    static let ringBlue = NSColor(calibratedRed: 0.24, green: 0.56, blue: 0.97, alpha: 1)
    /// 暂停：黄
    static let ringYellow = NSColor(calibratedRed: 0.93, green: 0.67, blue: 0.13, alpha: 1)
    static let breakGreen = ringMint
}

extension Color {
    static let ringGreen = Color(red: 0.16, green: 0.74, blue: 0.44)
    static let ringMint = Color(red: 0.36, green: 0.84, blue: 0.58)
    static let tomatoRed = Color(red: 0.91, green: 0.26, blue: 0.22)
    static let ringBlue = Color(red: 0.24, green: 0.56, blue: 0.97)
    static let ringYellow = Color(red: 0.93, green: 0.67, blue: 0.13)
    static let breakGreen = ringMint
}

/// 轻量文件日志，便于排查通知等问题（也写到 unified log）。
enum AppLog {
    private static let url: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let dir = base.appendingPathComponent("TomatoRing", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("runtime.log")
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func write(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        NSLog("%@", message)
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
