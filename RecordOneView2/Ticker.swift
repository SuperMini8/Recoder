//
//  Ticker.swift
//  Record_02
//
//  更新畫面用的計時器，封裝 Timer 的生命週期管理
//

import Foundation
/// 專門處理 Timer
final class Ticker {

    private var timer: Timer?

    /// 每次觸發時要做的事
    var onTick: (() -> Void)?

    /// 計時器是否正在執行
    var isRunning: Bool { timer != nil }

    /// 開始計時（會先停止舊的，保證不會重複啟動）
    func start(interval: TimeInterval) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onTick?()
        }
    }

    /// 停止計時
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stop() }
}
