//
//  CorePlayerWindow.swift
//  PlayerExt
//
//  Created by 吴哲 on 2024/4/1.
//

import MediaPlayer.MPVolumeView
import UIKit

/// 常驻音量控制window层
final class CorePlayerVolumeWindow: UIWindow {
    /// 音量控制器
    private let volumeController = CorePlayerVolumeController()

    /// 初始化
    /// - Parameter previousKeyWindow: 当前keyWindow
    private init(previousKeyWindow: UIWindow?) {
        if let previousKeyWindow = previousKeyWindow {
            if let windowScene = previousKeyWindow.windowScene {
                super.init(windowScene: windowScene)
            } else {
                super.init(frame: previousKeyWindow.bounds)
            }
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        backgroundColor = .black
        windowLevel = .init(-99999)
        rootViewController = volumeController
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 音量控制层
    private static var volumeWindow: CorePlayerVolumeWindow?

    /// 注册音量控制层
    private static func registerVolumeWindow() {
        guard volumeWindow == nil else { return }
        let previousKeyWindow = UIApplication.shared.keyWindow
        let volumeWindow = CorePlayerVolumeWindow(previousKeyWindow: previousKeyWindow)
        volumeWindow.makeKeyAndVisible()
        self.volumeWindow = volumeWindow
        previousKeyWindow?.makeKeyAndVisible()
    }

    /// 计数器
    private static var counter: Int = 10

    /// 设置音量
    /// - Parameters:
    ///   - size: 音大小
    ///   - animated: 是否执行滑块动画
    static func setVolume(_ size: Float, animated: Bool) {
        registerVolumeWindow()
        guard let volumeSlide = volumeWindow?.volumeController.getSystemVolumeSlide() else {
            // 这里配置一个延时设置 允许最多十次遍历层级
            // 如果十次都遍历不到层级、说明系统控件层级发生了变化
            guard counter > 0 else {
                assertionFailure("MPVolumeView 层级发生改变")
                return
            }
            counter -= 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setVolume(size, animated: animated)
            }
            return
        }
        let size = max(0, min(1, size))
        volumeSlide.setValue(size, animated: animated)
        volumeSlide.sendActions(for: .touchUpInside)
    }
}

/// 常驻音量控制器
private class CorePlayerVolumeController: UIViewController {
    /// 音量控制
    private lazy var volumeView = MPVolumeView()
    /// 蒙版
    private let maskView = UIView()
    /// 音量控制滑块
    private var volumeSlide: UISlider?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(volumeView)
        volumeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            volumeView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            volumeView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            volumeView.widthAnchor.constraint(equalToConstant: 200),
            volumeView.heightAnchor.constraint(equalToConstant: 150),
        ])
        maskView.backgroundColor = .black
        view.addSubview(maskView)
        maskView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            maskView.topAnchor.constraint(equalTo: view.topAnchor),
            maskView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            maskView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            maskView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        view.layoutIfNeeded()
        setNeedsGetVolumeSlide()
    }

    /// 获取音量控制器滑块
    /// - Returns: 系统滑块控件
    func getSystemVolumeSlide() -> UISlider? {
        setNeedsGetVolumeSlide()
        return volumeSlide
    }

    /// 获取滑块
    private func setNeedsGetVolumeSlide() {
        guard volumeSlide == nil else { return }
        volumeView.layoutIfNeeded()
        volumeView.setNeedsLayout()
        // 遍历MPVolumeView层级 获取系统音量滑块
        for subview in volumeView.subviews where type(of: subview).description() == "MPVolumeSlider" && subview is UISlider {
            volumeSlide = subview as! UISlider
            break
        }
    }
}
