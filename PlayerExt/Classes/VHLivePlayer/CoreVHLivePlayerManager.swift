//
//  CoreVHLivePlayerManager.swift
//  Pods
//
//  Created by 吴哲 on 2024/3/29.
//

import AVFoundation
import Foundation
import ZFPlayer

/// 微吼播放器
open class CoreVHLivePlayerManager: NSObject, CorePlayerMediaPlayback {
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
    open var volume: Float {
        get {
            // 微吼播放器无法单独控制音量
            AVAudioSession.sharedInstance().outputVolume
        }
        set {
            // 这里利用特殊手段设置手机系统的音量
            PlayerUtils.setSystemVolume(volume)
        }
    }

    /// 是否静音
    open var isMuted: Bool = false {
        didSet {
            vhPlayer?.setMute(isMuted)
        }
    }

    /// 播放速率
    @RateLimit
    open var rate: Float = 1 {
        didSet {
            vhPlayer?.rate = rate
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
            vhPlayer?.movieScalingMode = scalingMode.toVhScalingMode()
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
        initializePlayer()
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
        guard isPreparedToPlay, let vhPlayer = vhPlayer else {
            return prepareToPlay()
        }
        if !vhPlayer.reconnectPlay(), let param = PlayerUtils.queryParameters(assetURL) {
            vhPlayer.initialPlaybackTime = seekTime
            seekTime = 0
            vhPlayer.startPlayback(param)
        }
        if !seekTime.isZero {
            seek(toTime: seekTime, completionHandler: nil)
        }
        isPlaying = true
        playState = .playStatePlaying
    }

    /// 暂停播放
    open func pause() {
        if vhPlayer?.playerState != .pause {
            vhPlayer?.pausePlay()
        }
        isPlaying = false
        playState = .playStatePaused
    }

    /// 重新播放
    open func replay() {
        seek(toTime: 0) { finish in
            if !finish {
                self.play()
            }
        }
    }

    /// 停止播放
    open func stop() {
        guard let vhPlayer = vhPlayer else { return }
        loadState = []
        playState = .playStatePlayStopped
        presentationSize = .zero
        isPlaying = false
        vhPlayer.stopPlay()
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
        guard let vhPlayer = vhPlayer else {
            seekTime = time
            handler?(false)
            return
        }
        let total = vhPlayer.duration
        vhPlayer.currentPlaybackTime = total > time ? time : total - 1.0 // 直接到头就结束了,给1s缓冲
        seekTime = 0
        handler?(true)
    }

    /// 异步获取当前时间的缩略图
    open func thumbnailImage(atCurrentTime handler: @escaping (UIImage) -> Void) {
        vhPlayer?.takeVideoScreenshot { image in
            if let image = image {
                handler(image)
            }
        }
    }

    // MARK: PictureInPicture

    /// 是否支持画中画
    open func isSupportPictureInPicture() -> Bool {
        return false
    }

    /// 启动画中画
    open func startPictureInPicture() {}

    /// 结束画中画
    open func stopPictureInPicture() {}

    // MARK: VHallMoviePlayer

    /// 微吼播放器
    public private(set) var vhPlayer: VHallMoviePlayer?

    /// 首次缓存
    var isFirstBuffering = false
}

private extension ZFPlayerScalingMode {
    /// 转换缩放模式
    func toVhScalingMode() -> VHRTMPMovieScalingMode {
        switch self {
        case .aspectFit: return .aspectFit
        case .aspectFill: return .aspectFill
        default: return .none
        }
    }
}

public extension PlayerUtils {
    /// 配置微吼播放器地址
    /// - Parameters:
    ///   - roomId: 房间号
    ///   - recordId: 回放id
    ///   - accessToken: 授权token
    ///   - pass: 通行证
    ///   - name: 微吼用户名称
    ///   - email: 微吼用户邮箱
    /// - Returns: 播放地址
    static func vhPlayerAssetURL(roomId: String, recordId: String? = nil, accessToken: String? = nil, pass: String? = nil, name: String, email: String) -> URL? {
        assert(!roomId.isEmpty, "roomId can not empty")
        var param: [String: String] = [:]
        param["id"] = roomId
        if let recordId = recordId, !recordId.isEmpty {
            param["record_id"] = recordId == "0" ? "" : recordId
        }
        param["access_token"] = accessToken
        param["pass"] = pass
        param["name"] = name
        param["email"] = email
        var comp = URLComponents(url: URL(fileURLWithPath: "CorePlayer/VHPlayer"), resolvingAgainstBaseURL: false)
        comp?.queryItems = param.filter { !$0.1.isEmpty }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return comp?.url
    }
}

// MARK: - VHLivePlayer

extension CoreVHLivePlayerManager {
    /// 初始化播放器
    func initializePlayer() {
        // 初始化前先销毁上一个播放器
        destroyPlayer()
        vhPlayer = VHallMoviePlayer(delegate: self)
        vhPlayer?.rate = rate
        vhPlayer?.setMute(isMuted)
        vhPlayer?.movieScalingMode = scalingMode.toVhScalingMode()
        view.playerView = vhPlayer?.moviePlayerView
    }

    /// 销毁播放器
    @discardableResult
    func destroyPlayer() -> Bool {
        assert(Thread.isMainThread, "must in main thread")
        guard let vhPlayer = vhPlayer else {
            return false
        }
        vhPlayer.delegate = emptyDelegate
        vhPlayer.moviePlayerView?.isHidden = true
        vhPlayer.moviePlayerView?.removeFromSuperview()
        view.playerView = nil
        vhPlayer.destroyMoivePlayer()
        self.vhPlayer = nil
        return true
    }

    /// 更新缓冲状态
    /// - Parameter moviePlayer: 当前播放器
    func buffering(_ moviePlayer: VHallMoviePlayer) {
        // 停止播放
        guard playState != .playStatePlayStopped else { return }
        // 没有网络
        guard ZFReachabilityManager.shared().networkReachabilityStatus != .notReachable else { return }
        bufferTime = moviePlayer.playableDuration
        playerBufferTimeChanged?(self, bufferTime)
    }
}

// MARK: - VHallMoviePlayerDelegate

public let VHLivePlayerErrorDomain = "VHLivePlayerError"

extension CoreVHLivePlayerManager: VHallMoviePlayerDelegate {
    /// 播放连接成功回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - info: 相关信息
    public func connectSucceed(_: VHallMoviePlayer!, info _: [AnyHashable: Any]!) {
        totalTime = 0
        currentTime = 0
        bufferTime = 0
        loadState = .playthroughOK
        if let assetURL = assetURL {
            playerReadyToPlay?(self, assetURL)
        }
    }

    /// 缓冲开始回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - info: 相关信息
    public func bufferStart(_ moviePlayer: VHallMoviePlayer!, info _: [AnyHashable: Any]!) {
        PlayerUtils.uiPerform {
            if moviePlayer.playableDuration.isZero {
                self.isFirstBuffering = true
                self.loadState = .stalled
            }
            self.buffering(moviePlayer)
        }
    }

    /// 缓冲结束回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - info: 相关信息
    public func bufferStop(_ moviePlayer: VHallMoviePlayer!, info _: [AnyHashable: Any]!) {
        PlayerUtils.uiPerform {
            if self.isFirstBuffering {
                self.loadState = .playable
                self.isFirstBuffering = false
            }
            self.buffering(moviePlayer)
        }
    }

    /// 播放时错误的回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - livePlayErrorType: 直播错误类型
    ///   - info: 具体错误信息
    public func moviePlayer(_: VHallMoviePlayer!, playError _: VHSaasLivePlayErrorType, info: [AnyHashable: Any]!) {
        PlayerUtils.uiPerform {
            self.playState = .playStatePlayFailed
            self.isPlaying = false
            if self.playerPlayFailed != nil {
                let userInfo = info as? [String: Any] ?? [:]
                let error = NSError(domain: VHLivePlayerErrorDomain, code: 0, userInfo: userInfo)
                self.playerPlayFailed?(self, error)
            }
        }
    }

    /// 当前活动状态回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - state: 活动状态
    public func moviePlayer(_ moviePlayer: VHallMoviePlayer!, statusDidChange state: VHPlayerState) {
        PlayerUtils.uiPerform {
            if !moviePlayer.duration.isZero {
                if self.totalTime != moviePlayer.duration {
                    self.totalTime = moviePlayer.duration
                    self.playerPlayTimeChanged?(self, moviePlayer.currentPlaybackTime, moviePlayer.duration)
                }
            }
            if case .complete = state {
                self.playState = .playStatePlayStopped
                self.playerDidToEnd?(self)
            }
        }
    }

    /// 视频宽髙回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - size: 视频尺寸
    public func moviePlayer(_: VHallMoviePlayer!, videoSize size: CGSize) {
        PlayerUtils.uiPerform {
            self.presentationSize = size
        }
    }

    /// 当前播放时间回调
    /// - Parameters:
    ///   - moviePlayer: 播放器
    ///   - currentTime: 播放时间点 1s回调一次
    public func moviePlayer(_ moviePlayer: VHallMoviePlayer!, currentTime: TimeInterval) {
        PlayerUtils.uiPerform {
            if !moviePlayer.duration.isZero {
                self.currentTime = currentTime
                self.playerPlayTimeChanged?(self, currentTime, moviePlayer.duration)
                if self.bufferTime != moviePlayer.playableDuration {
                    self.buffering(moviePlayer)
                }
            }
        }
    }
}

// MARK: - Empty VHallMoviePlayerDelegate

// 发现微吼播放器实例在切换清空delegate的时候会crash 这里用个空代理来替换不响应事件
private class EmptyVHallMoviePlayerDelegate: NSObject, VHallMoviePlayerDelegate {}
private let emptyDelegate = EmptyVHallMoviePlayerDelegate()
