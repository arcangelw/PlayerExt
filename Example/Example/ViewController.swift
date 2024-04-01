//
//  ViewController.swift
//  Example
//
//  Created by 吴哲 on 2024/4/1.
//

import PlayerExt
import UIKit

final class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            PlayerUtils.setSystemVolume(1)
        }
    }
}
