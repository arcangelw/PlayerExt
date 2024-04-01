//
//  CoreTXLiteAVPlayerManager.swift
//  Pods
//
//  Created by 吴哲 on 2024/3/29.
//

import AVFoundation
import Foundation
import TXLiteAVSDK_Player
import ZFPlayer

/// 腾讯播放器
open class CoreTXLiteAVPlayerManager: NSObject, CorePlayerMediaPlayback {
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
            txPlayer?.setAudioPlayoutVolume(.init(volume * 100))
        }
    }

    /// 是否静音
    open var isMuted: Bool = false {
        didSet {
            txPlayer?.setMute(isMuted)
        }
    }

    /// 播放速率
    @RateLimit
    open var rate: Float = 1 {
        didSet {
            txPlayer?.setRate(rate)
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
            txPlayer?.setRenderMode(scalingMode.toTxScalingMode())
        }
    }

    /// 是否准备好播放
    public private(set) var isPreparedToPlay: Bool = false

    /// 是否自动播放
    open var shouldAutoPlay: Bool = false

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
        guard isPreparedToPlay, let txPlayer = txPlayer else {
            return prepareToPlay()
        }
        txPlayer.resume()
        isPlaying = true
        playState = .playStatePlaying
    }

    /// 暂停播放
    open func pause() {
        txPlayer?.pause()
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
        guard let txPlayer = txPlayer else { return }
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
        guard let txPlayer = txPlayer, !totalTime.isZero else {
            seekTime = time
            handler?(false)
            return
        }
        txPlayer.seek(.init(time))
        seekHandler = handler
        seekTime = 0
    }

    /// 异步获取当前时间的缩略图
    open func thumbnailImage(atCurrentTime handler: @escaping (UIImage) -> Void) {
        guard let txPlayer = txPlayer else { return }
        txPlayer.snapshot { image in
            if let image = image {
                handler(image)
            }
        }
    }

    // MARK: PictureInPicture

    /// 是否支持画中画
    open func isSupportPictureInPicture() -> Bool {
        return TXVodPlayer.isSupportPictureInPicture()
    }

    /// 启动画中画
    open func startPictureInPicture() {
        guard isSupportPictureInPicture(), let txPlayer = txPlayer else {
            return
        }
        txPlayer.enterPictureInPicture()
    }

    /// 结束画中画
    open func stopPictureInPicture() {
        guard isSupportPictureInPicture(), let txPlayer = txPlayer else {
            return
        }
        txPlayer.exitPictureInPicture()
    }

    // MARK: - TXLivePlayer

    /// 腾讯播放器
    public private(set) var txPlayer: TXVodPlayer?

    /// 首次缓存
    var isFirstBuffering = false

    /// 跳转事件
    var seekHandler: ((Bool) -> Void)?
}

private extension ZFPlayerScalingMode {
    /// 转换缩放模式
    func toTxScalingMode() -> TX_Enum_Type_RenderMode {
        switch self {
        case .aspectFill: return .RENDER_MODE_FILL_SCREEN
        default: return .RENDER_MODE_FILL_EDGE
        }
    }
}

extension CoreTXLiteAVPlayerManager {
    /// 初始化播放器
    func initializePlayer(_ assetURL: URL) {
        // 初始化前先销毁上一个播放器
        destroyPlayer()
        txPlayer = TXVodPlayer()
        txPlayer?.vodDelegate = self
        txPlayer?.isAutoPlay = false
        let config = TXVodPlayConfig()
        config.progressInterval = 0.25
        config.maxBufferSize = 10
        txPlayer?.config = config
        txPlayer?.setAudioPlayoutVolume(.init(volume * 100))
        txPlayer?.setRate(rate)
        txPlayer?.setMute(isMuted)
        txPlayer?.setRenderMode(scalingMode.toTxScalingMode())
        view.playerView = .init()
        txPlayer?.setupVideoWidget(view.playerView, insert: 0)
        txPlayer?.startVodPlay(assetURL.absoluteString)
    }

    /// 销毁播放器
    @discardableResult
    func destroyPlayer() -> Bool {
        assert(Thread.isMainThread, "must in main thread")
        guard let txPlayer = txPlayer else {
            return false
        }
        txPlayer.delegate = nil
        txPlayer.stopPlay()
        txPlayer.removeVideoWidget()
        view.playerView.isHidden = true
        view.playerView.removeFromSuperview()
        view.playerView = nil
        self.txPlayer = nil
        return true
    }

    /// 更新缓冲状态
    /// - Parameter player: 当前播放器
    func buffering(_ player: TXVodPlayer) {
        // 停止播放
        guard playState != .playStatePlayStopped else { return }
        // 没有网络
        guard ZFReachabilityManager.shared().networkReachabilityStatus != .notReachable else { return }
        bufferTime = .init(player.playableDuration())
        playerBufferTimeChanged?(self, bufferTime)
    }
}

// MARK: - TXVodPlayListener

public let TXLiteAVPlayerErrorDomain = "TXLiteAVPlayerError"

extension CoreTXLiteAVPlayerManager: TXVodPlayListener {
    /// 点播事件通知
    /// - Parameters:
    ///   - player: 播放器
    ///   - EvtID: 事件id
    ///   - param: 事件参数
    public func onPlayEvent(_ player: TXVodPlayer!, event EvtID: Int32, withParam param: [AnyHashable: Any]!) {
        PlayerUtils.uiPerform {
            let eventId = TXVODEventID(rawValue: EvtID)
            switch eventId {
            case VOD_PLAY_EVT_VOD_PLAY_FIRST_VIDEO_PACKET:
                // 首帧显示事件
                if !self.seekTime.isZero {
                    self.seek(toTime: self.seekTime, completionHandler: nil)
                }
            case VOD_PLAY_EVT_VOD_PLAY_PREPARED:
                // 准备完成
                self.currentTime = 0
                self.bufferTime = 0
                self.loadState = .playthroughOK
                if let assetURL = self.assetURL {
                    self.playerReadyToPlay?(self, assetURL)
                }
                self.presentationSize = CGSize(width: CGFloat(player.width()), height: CGFloat(player.height()))
            case VOD_PLAY_EVT_PLAY_LOADING:
                // 数据缓冲中
                if player.playableDuration() == 0 {
                    self.isFirstBuffering = true
                    self.loadState = .stalled
                }
                self.buffering(player)
            case VOD_PLAY_EVT_VOD_LOADING_END:
                // 视频缓冲结束
                // 缓冲完成事件
                if self.isFirstBuffering {
                    self.loadState = .playable
                    self.isFirstBuffering = false
                }
                self.buffering(player)
            case VOD_PLAY_EVT_VOD_PLAY_SEEK_COMPLETE:
                // 跳转完成事件
                self.seekHandler?(true)
                self.seekHandler = nil
            case VOD_PLAY_EVT_PLAY_BEGIN, VOD_PLAY_EVT_PLAY_PROGRESS:
                // 播放已经开始、播放进度更新
                self.totalTime = .init(player.duration())
                self.currentTime = .init(player.currentPlaybackTime())
                if !self.totalTime.isZero {
                    self.playerPlayTimeChanged?(self, self.currentTime, self.totalTime)
                }
            case VOD_PLAY_EVT_PLAY_END:
                // 播放已经结束
                self.playState = .playStatePlayStopped
                self.playerDidToEnd?(self)
            case let eventId where self.allErrorEventIds.contains(eventId):
                // 播放错误
                self.seekHandler?(false)
                self.seekHandler = nil
                self.playState = .playStatePlayFailed
                self.isPlaying = false
                if self.playerPlayFailed != nil {
                    let userInfo = param as? [String: Any] ?? [:]
                    let error = NSError(domain: TXLiteAVPlayerErrorDomain, code: 0, userInfo: userInfo)
                    self.playerPlayFailed?(self, error)
                }
            default: ()
            }
        }
    }

    /// 所有错误事件
    private var allErrorEventIds: [TXVODEventID] {
        return [
            /// 直播错误: 网络连接断开（已经经过三次重试并且未能重连成功）
            VOD_PLAY_ERR_NET_DISCONNECT,

            /// 点播错误: 播放文件不存在
            VOD_PLAY_ERR_FILE_NOT_FOUND,

            /// 点播错误: HLS 解码 KEY 获取失败
            VOD_PLAY_ERR_HLS_KEY,

            /// 点播错误: 获取点播文件的文件信息失败
            VOD_PLAY_ERR_GET_PLAYINFO_FAIL,

            /// licence 检查失败
            VOD_PLAY_ERR_LICENCE_CHECK_FAIL,

            /// 未知错误。
            VOD_PLAY_ERR_UNKNOW,

            /// 通用错误码。
            VOD_PLAY_ERR_GENERAL,

            /// 解封装失败。
            VOD_PLAY_ERR_DEMUXER_FAIL,

            /// 系统播放器播放错误。
            VOD_PLAY_ERR_SYSTEM_PLAY_FAIL,

            /// 解封装超时。
            VOD_PLAY_ERR_DEMUXER_TIMEOUT,

            /// 视频解码错误。
            VOD_PLAY_ERR_DECODE_VIDEO_FAIL,

            /// 音频解码错误。
            VOD_PLAY_ERR_DECODE_AUDIO_FAIL,

            /// 字幕解码错误。
            VOD_PLAY_ERR_DECODE_SUBTITLE_FAIL,

            /// 视频渲染错误。
            VOD_PLAY_ERR_RENDER_FAIL,
            /// 视频后处理错误。
            VOD_PLAY_ERR_PROCESS_VIDEO_FAIL,
            /// 视频下载出错。
            VOD_PLAY_ERR_DOWNLOAD_FAIL,
        ]
    }
}
