//
//  CoreAliPlayerManager.swift
//  Pods
//
//  Created by 吴哲 on 2024/3/29.
//

import AliyunPlayer
import AVFoundation
import Foundation
import ZFPlayer

/// 阿里播放器
open class CoreAliPlayerManager: NSObject, CorePlayerMediaPlayback {
    override public init() {
        super.init()
    }

    /// 销毁播放器
    deinit {
        destroyPlayer()
    }

    // MARK: - CorePlayerMediaPlayback

    /// 播放器视图
    public lazy var view: ZFPlayerView = .init()

    /// 音量
    @VolumeLimit
    open var volume: Float = AVAudioSession.sharedInstance().outputVolume {
        didSet {
            aliPlayer?.volume = volume
        }
    }

    /// 是否静音
    open var isMuted: Bool = false {
        didSet {
            aliPlayer?.isMuted = isMuted
        }
    }

    /// 播放速率
    @RateLimit
    open var rate: Float = 1 {
        didSet {
            aliPlayer?.rate = rate
        }
    }

    /// 当前播放时间
    public private(set) var currentTime: TimeInterval = 0

    /// 总播放时间
    public private(set) var totalTime: TimeInterval = 0

    /// 缓冲时间
    public private(set) var bufferTime: TimeInterval = 0

    /// 跳转播放时间
    open var seekTime: TimeInterval = 0

    /// 是否正在播放
    public private(set) var isPlaying: Bool = false

    /// 缩放模式
    open var scalingMode: ZFPlayerScalingMode = .aspectFill {
        didSet {
            view.scalingMode = scalingMode
            aliPlayer?.scalingMode = scalingMode.toAliScalingMode()
        }
    }

    /// 是否准备好播放
    public private(set) var isPreparedToPlay: Bool = false

    /// 是否自动播放
    open var shouldAutoPlay: Bool = true

    /// 播放资源URL
    private var _assetURL: URL?
    open var assetURL: URL? {
        get {
            return _assetURL
        }
        set {
            stop()
            _assetURL = newValue
            prepareToPlay()
        }
    }

    /// 显示大小
    open var presentationSize: CGSize = .zero {
        didSet {
            view.presentationSize = presentationSize
            presentationSizeChanged?(self, presentationSize)
        }
    }

    /// 播放状态
    public private(set) var playState: ZFPlayerPlaybackState = .playStateUnknown {
        didSet {
            playerPlayStateChanged?(self, playState)
        }
    }

    /// 加载状态
    public private(set) var loadState: ZFPlayerLoadState = [] {
        didSet {
            playerLoadStateChanged?(self, loadState)
        }
    }

    /// 准备播放回调
    public var playerPrepareToPlay: ((any ZFPlayerMediaPlayback, URL) -> Void)?

    /// 准备好播放回调
    public var playerReadyToPlay: ((any ZFPlayerMediaPlayback, URL) -> Void)?

    /// 播放时间改变回调
    public var playerPlayTimeChanged: ((any ZFPlayerMediaPlayback, TimeInterval, TimeInterval) -> Void)?

    /// 缓冲时间改变回调
    public var playerBufferTimeChanged: ((any ZFPlayerMediaPlayback, TimeInterval) -> Void)?

    /// 播放状态改变回调
    public var playerPlayStateChanged: ((any ZFPlayerMediaPlayback, ZFPlayerPlaybackState) -> Void)?

    /// 加载状态改变回调
    public var playerLoadStateChanged: ((any ZFPlayerMediaPlayback, ZFPlayerLoadState) -> Void)?

    /// 播放失败回调
    public var playerPlayFailed: ((any ZFPlayerMediaPlayback, Any) -> Void)?

    /// 播放结束回调
    public var playerDidToEnd: ((any ZFPlayerMediaPlayback) -> Void)?

    /// 显示大小改变回调
    public var presentationSizeChanged: ((any ZFPlayerMediaPlayback, CGSize) -> Void)?

    /// 准备播放
    open func prepareToPlay() {
        guard let assetURL = assetURL else { return }
        isPreparedToPlay = true
        initializePlayer(assetURL)
        if shouldAutoPlay {
            play()
        }
        loadState = .prepare
        playerPrepareToPlay?(self, assetURL)
    }

    /// 重新加载播放器
    open func reloadPlayer() {
        seekTime = currentTime
        prepareToPlay()
    }

    /// 开始播放
    open func play() {
        guard isPreparedToPlay, let aliPlayer = aliPlayer else {
            return prepareToPlay()
        }
        aliPlayer.start()
        isPlaying = true
        playState = .playStatePlaying
    }

    /// 暂停播放
    open func pause() {
        aliPlayer?.pause()
        isPlaying = false
        playState = .playStatePaused
    }

    /// 重新播放
    open func replay() {
        seek(toTime: 0) { finish in
            if finish {
                self.play()
            }
        }
    }

    /// 停止播放
    open func stop() {
        guard let aliPlayer = aliPlayer else { return }
        loadState = []
        playState = .playStatePlayStopped
        presentationSize = .zero
        isPlaying = false
        destroyPlayer()
        isPreparedToPlay = false
        _assetURL = nil
        currentTime = 0
        totalTime = 0
        bufferTime = 0
        isFirstBuffering = false
    }

    /// 跳转到指定时间播放
    @objc(seekToTime:completionHandler:)
    open func seek(toTime time: TimeInterval, completionHandler handler: ((Bool) -> Void)?) {
        guard let aliPlayer = aliPlayer, !totalTime.isZero else {
            seekTime = time
            handler?(false)
            return
        }
        seekHandler = handler
        aliPlayer.seek(toTime: .init(time * 1000), seekMode: AVP_SEEKMODE_ACCURATE)
        seekTime = 0
    }

    /// 异步获取当前时间的缩略图
    open func thumbnailImage(atCurrentTime handler: @escaping (UIImage) -> Void) {
        guard let aliPlayer = aliPlayer else { return }
        thumbnailHandler = handler
        aliPlayer.getThumbnail(aliPlayer.currentPosition)
    }

    // MARK: PictureInPicture

    /// 是否支持画中画
    open func isSupportPictureInPicture() -> Bool {
        if #available(iOS 15.0, *) {
            return true
        }
        return false
    }

    /// 启动画中画
    open func startPictureInPicture() {
        guard isSupportPictureInPicture(), let aliPlayer = aliPlayer else {
            return
        }
        aliPlayer.setPictureInPictureEnable(true)
    }

    /// 结束画中画
    open func stopPictureInPicture() {
        guard isSupportPictureInPicture(), let aliPlayer = aliPlayer else {
            return
        }
        aliPlayer.setPictureInPictureEnable(false)
    }

    // MARK: - AliPlayer

    /// 阿里云播放器
    public private(set) var aliPlayer: AliPlayer?

    /// 当前播放时间
    var aliCurrentTime: TimeShift = 0 {
        didSet {
            currentTime = aliCurrentTime.second
        }
    }

    /// 总播放时间
    var aliTotalTime: TimeShift = 0 {
        didSet {
            totalTime = aliTotalTime.second
        }
    }

    /// 缓冲时间
    var aliBufferTime: TimeShift = 0 {
        didSet {
            bufferTime = aliBufferTime.second
        }
    }

    /// 首次缓存
    var isFirstBuffering = false

    /// 跳转事件
    var seekHandler: ((Bool) -> Void)?

    /// 截图回调
    var thumbnailHandler: ((UIImage) -> Void)?
}

private extension ZFPlayerScalingMode {
    /// 转换缩放模式
    func toAliScalingMode() -> AVPScalingMode {
        switch self {
        case .aspectFit: return AVP_SCALINGMODE_SCALEASPECTFIT
        case .aspectFill: return AVP_SCALINGMODE_SCALEASPECTFILL
        default: return AVP_SCALINGMODE_SCALETOFILL
        }
    }
}

extension CoreAliPlayerManager {
    /// 初始化播放器
    func initializePlayer(_ assetURL: URL) {
        // 初始化前先销毁上一个播放器
        destroyPlayer()
        aliPlayer = AliPlayer()
        aliPlayer?.isAutoPlay = false
        let config = aliPlayer?.getConfig()
        // 设置网络超时时间，单位ms
        config?.networkTimeout = 2000
        // 设置超时重试次数。每次重试间隔为networkTimeout。networkRetryCount=0则表示不重试，重试策略app决定，默认值为2
        config?.networkRetryCount = 2
        aliPlayer?.setConfig(config)
        aliPlayer?.delegate = self
        aliPlayer?.scalingMode = scalingMode.toAliScalingMode()
        aliPlayer?.volume = volume
        aliPlayer?.rate = rate
        aliPlayer?.isMuted = isMuted
        view.playerView = aliPlayer?.playerView
        let urlSource = AVPUrlSource()
        urlSource.playerUrl = assetURL
        aliPlayer?.setUrlSource(urlSource)
        aliPlayer?.prepare()
    }

    /// 销毁播放器
    @discardableResult
    func destroyPlayer() -> Bool {
        assert(Thread.isMainThread, "must in main thread")
        guard let aliPlayer = aliPlayer else {
            return false
        }
        aliPlayer.delegate = nil
        aliPlayer.stop()
        aliPlayer.playerView?.isHidden = true
        aliPlayer.playerView.removeFromSuperview()
        aliPlayer.destroy()
        view.playerView = nil
        self.aliPlayer = nil
        return true
    }

    /// 更新缓冲状态
    /// - Parameter position: 视频当前缓存位置
    func buffering(_ position: Int64) {
        // 停止播放
        guard playState != .playStatePlayStopped else { return }
        // 没有网络
        guard ZFReachabilityManager.shared().networkReachabilityStatus != .notReachable else { return }
        aliBufferTime = TimeShift(position)
        playerBufferTimeChanged?(self, bufferTime)
    }
}

// MARK: - AVPDelegate

public let AliPlayerErrorDomain = "AliPlayerError"

extension CoreAliPlayerManager: AVPDelegate {
    /// 播放器事件回调
    /// - Parameters:
    ///   - player: 播放器
    ///   - eventType: 播放器事件类型
    public func onPlayerEvent(_ player: AliPlayer!, eventType: AVPEventType) {
        PlayerUtils.uiPerform {
            let aliTotalTime = TimeShift(player.duration)
            if aliTotalTime.millisecond > 0, self.aliTotalTime != aliTotalTime {
                self.aliTotalTime = aliTotalTime
                self.aliCurrentTime = .init(player.currentPosition)
                self.playerPlayTimeChanged?(self, self.currentTime, self.totalTime)
            }
            switch eventType {
            case AVPEventPrepareDone:
                // 准备完成
                self.currentTime = 0
                self.bufferTime = 0
                self.loadState = .playthroughOK
                if let assetURL = self.assetURL {
                    self.playerReadyToPlay?(self, assetURL)
                }
            case AVPEventFirstRenderedStart:
                // 首帧显示事件
                if !self.seekTime.isZero {
                    self.seek(toTime: self.seekTime, completionHandler: nil)
                }
            case AVPEventCompletion:
                // 播放完成
                self.playState = .playStatePlayStopped
                self.playerDidToEnd?(self)
            case AVPEventLoadingStart:
                // 缓冲开始事件
                if player.bufferedPosition == 0 {
                    self.isFirstBuffering = true
                    self.loadState = .stalled
                }
                self.buffering(player.bufferedPosition)
            case AVPEventLoadingEnd:
                // 缓冲完成事件
                if self.isFirstBuffering {
                    self.loadState = .playable
                    self.isFirstBuffering = false
                }
                self.buffering(player.bufferedPosition)
            case AVPEventSeekEnd:
                // 跳转完成事件
                self.seekHandler?(true)
                self.seekHandler = nil
            default: ()
            }
        }
    }

    /// 错误代理回调
    /// - Parameters:
    ///   - player: 播放器
    ///   - errorModel: 错误信息
    public func onError(_: AliPlayer!, errorModel: AVPErrorModel!) {
        PlayerUtils.uiPerform {
            self.seekHandler?(false)
            self.seekHandler = nil
            self.playState = .playStatePlayFailed
            self.isPlaying = false
            if self.playerPlayFailed != nil {
                var userInfo: [String: Any] = [:]
                if errorModel != nil {
                    userInfo["code"] = errorModel.code
                    userInfo["message"] = errorModel.message
                    userInfo["extra"] = errorModel.extra
                    userInfo["requestId"] = errorModel.requestId
                    userInfo["videoId"] = errorModel.videoId
                }
                let error = NSError(domain: AliPlayerErrorDomain, code: 0, userInfo: userInfo)
                self.playerPlayFailed?(self, error)
            }
        }
    }

    /// 视频大小变化回调
    /// - Parameters:
    ///   - player: 播放器
    ///   - width: 视频宽度
    ///   - height: 视频高度
    ///   - rotation: 视频旋转角度
    public func onVideoSizeChanged(_: AliPlayer!, width: Int32, height: Int32, rotation _: Int32) {
        PlayerUtils.uiPerform {
            self.presentationSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        }
    }

    /// 视频当前播放位置回调
    /// - Parameters:
    ///   - player: 播放器
    ///   - position:  视频当前播放位置
    public func onCurrentPositionUpdate(_: AliPlayer!, position: Int64) {
        PlayerUtils.uiPerform {
            if !self.totalTime.isZero {
                self.aliCurrentTime = .init(position)
                self.playerPlayTimeChanged?(self, self.currentTime, self.totalTime)
            }
        }
    }

    /// 视频缓存位置回调
    /// - Parameters:
    ///   - player: 播放器player指针
    ///   - position: 视频当前缓存位置
    public func onBufferedPositionUpdate(_: AliPlayer!, position: Int64) {
        PlayerUtils.uiPerform {
            if self.aliBufferTime.millisecond != position {
                self.buffering(position)
            }
        }
    }

    /// 获取缩略图成功回调
    /// - Parameters:
    ///   - positionMs: 指定的缩略图位置
    ///   - fromPos: 此缩略图的开始位置
    ///   - toPos: 此缩略图的结束位置
    ///   - image: 缩图略图像
    public func onGetThumbnailSuc(_: Int64, fromPos _: Int64, toPos _: Int64, image: Any!) {
        guard let image = image as? UIImage else { return }
        PlayerUtils.uiPerform {
            self.thumbnailHandler?(image)
            self.thumbnailHandler = nil
        }
    }
}
