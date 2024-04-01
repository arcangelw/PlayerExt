//
//  PlayerUtils.swift
//  Pods
//
//  Created by 吴哲 on 2024/4/1.
//

import Foundation
import UIKit

public enum PlayerUtils {
    /// Dictionary of the URL's query parameters that have values.
    ///
    /// Duplicated query keys are ignored, taking only the first instance.
    public static func queryParameters(_ url: URL?) -> [String: String]? {
        guard let queryItems = url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) })?.queryItems else {
            return nil
        }
        return Dictionary(queryItems.lazy.compactMap {
            guard let value = $0.value else { return nil }
            return ($0.name, value)
        }) { first, _ in first }
    }

    public static func uiPerform(_ work: @escaping @Sendable @convention(block) () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// 设置系统音量
    /// - Parameter size: 目标音量
    public static func setSystemVolume(_ size: Float) {
        CorePlayerVolumeWindow.setVolume(size, animated: false)
    }
}

/// 音量限制
@propertyWrapper
public class VolumeLimit {
    private var value: Float
    public var wrappedValue: Float {
        get {
            return value
        }
        set {
            value = max(0.0, min(1.0, newValue))
        }
    }

    public init(wrappedValue: Float) {
        value = max(0.0, min(1.0, wrappedValue))
    }
}

/// 播放限速
@propertyWrapper
public class RateLimit {
    private var value: Float
    public var wrappedValue: Float {
        get {
            return value
        }
        set {
            value = max(0.5, min(2.0, newValue))
        }
    }

    public init(wrappedValue: Float) {
        value = max(0.5, min(2.0, wrappedValue))
    }
}

/// 时间转换
struct TimeShift: Equatable, ExpressibleByIntegerLiteral {
    /// 毫秒时间
    var millisecond: Int64
    /// 秒
    var second: TimeInterval {
        return TimeInterval(millisecond) * 0.001
    }

    static func == (lhs: TimeShift, rhs: TimeShift) -> Bool {
        return lhs.millisecond == rhs.millisecond
    }

    init(_ millisecond: Int64) {
        self.millisecond = millisecond
    }

    init(integerLiteral value: Int64) {
        self.init(value)
    }
}
