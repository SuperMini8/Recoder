//
//  AudioPlayerService.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import AVFoundation

final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {

    private var player : AVAudioPlayer?

    /// 播放自然結束時的回呼（手動 stop 不會觸發）
    var onFinishPlaying: (() -> Void)?

    /// 判斷需不需要設置播放器
    func isNeedSetPlayer() -> Bool {
        return player == nil
    }
    /// 設置播放器
    func setPlayer(_ recordData: RecordData) throws {
        if player == nil {
            let dataURL = try recordData.fileURL()
            player = try AVAudioPlayer(contentsOf: dataURL)
            player?.delegate = self
        }
    }
    /// 播放
    func play() {
        guard let player else { return }
        player.prepareToPlay()
        player.play()
    }
    
    /// 暫停
    func pause() {
        guard let player else { return }
        player.pause()
    }
    
    /// 停止（錄音結束）
    func stop() {
        guard let player else { return }
        player.stop()
    }
    
    /// 清除播放器設置
    func clearPlayer() {
        player = nil
    }
    
    /// 取得目前播放的時間軸
    func getPlayingCurrentTime() -> Double {
        guard let player else { return 0.0 }
        return player.currentTime
    }
    /// 設置要播放的時間軸
    func setPlayingCurrentTime(_ time: Double)  {
        guard let player else { return }
        player.currentTime = time
    }

    // MARK: - AVAudioPlayerDelegate
    /// 播放到結尾自然結束時觸發（AVAudioPlayer 在啟動播放的執行緒上回呼，此處即主執行緒）
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinishPlaying?()
    }
}
