//
//  CorePlayerMediaPlayback.swift
//  Pods
//
//  Created by 吴哲 on 2024/3/29.
//

import AVFoundation
import Foundation
import ZFPlayer

/// 核心媒体播放器
public protocol CorePlayerMediaPlayback: ZFPlayerMediaPlayback {
    /// 是否支持画中画
    func isSupportPictureInPicture() -> Bool
    /// 启动画中画
    func startPictureInPicture()
    /// 结束画中画
    func stopPictureInPicture()
}

public extension ZFPlayerController {
    /// 核心播放器
    var corePlayerManager: CorePlayerMediaPlayback {
        return currentPlayerManager as! CorePlayerMediaPlayback
    }
}
