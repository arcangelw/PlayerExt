//
//  CoreAVPlayerManager.swift
//  Pods
//
//  Created by 吴哲 on 2024/3/29.
//

import AVKit
import Foundation
import ZFPlayer

/// AVPlayer
open class CoreAVPlayerManager: ZFAVPlayerManager, CorePlayerMediaPlayback {
    /// 音量
    override open var volume: Float {
        get {
            super.volume
        }
        set {
            super.volume = max(0.0, min(1.0, newValue))
        }
    }

    /// 播放速率
    override open var rate: Float {
        get {
            super.rate
        }
        set {
            super.rate = max(0.5, min(2.0, newValue))
        }
    }

    /// 配置画中画
//    ZFAVPlayerManager *manager = (ZFAVPlayerManager *)self.player.currentPlayerManager;
//    AVPictureInPictureController *vc = [[AVPictureInPictureController alloc] initWithPlayerLayer:manager.avPlayerLayer];
//

    // MARK: PictureInPicture

    private var pictureInPictureController: AVPictureInPictureController?

    /// 是否支持画中画
    open func isSupportPictureInPicture() -> Bool {
        return AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// 启动画中画
    open func startPictureInPicture() {
        guard isSupportPictureInPicture(), let avPlayerLayer = avPlayerLayer else { return }
        pictureInPictureController = AVPictureInPictureController(playerLayer: avPlayerLayer)
        pictureInPictureController?.delegate = self
        /// 要有延迟 否则可能开启不成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.pictureInPictureController?.startPictureInPicture()
        }
    }

    /// 结束画中画
    open func stopPictureInPicture() {
        pictureInPictureController?.stopPictureInPicture()
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension CoreAVPlayerManager: AVPictureInPictureControllerDelegate {
    /// 画中画停止的时候销毁控制器
    public func pictureInPictureControllerDidStopPictureInPicture(_: AVPictureInPictureController) {
        pictureInPictureController = nil
    }
}
