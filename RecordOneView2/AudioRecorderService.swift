//
//  AudioRecorderService.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import AVFoundation

final class AudioRecorderService {
    
    private var recorder : AVAudioRecorder?
    
    /// 檢查麥克風權限，有可能會 requestRecordPermission，completion 動到 UI 須在 Main 上
    @discardableResult
    func checkRecordPermission(completion: ((Bool) -> Void)? = nil) -> Bool? {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                AVAudioApplication.requestRecordPermission { isAgree in
                    completion?(isAgree)
                }
                return nil
            case .denied:
                completion?(false)
                return false
            case .granted:
                completion?(true)
                return true
            @unknown default:
                fatalError("系統權限錯誤")
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission{ isAgree in
                    completion?(isAgree)
                }
                return nil
            case .denied:
                completion?(false)
                return false
            case .granted:
                completion?(true)
                return true
            @unknown default:
                fatalError("系統權限錯誤")
            }
        }
    }
    
    /// 系統相關設置
    func setSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        // 設定系統分類，同時需要「錄」與「播」使用 playAndRecord
        // mode 語音備忘錄、一般錄音: 使用 default
        // option: playAndRecord 時，播放預設走聽筒，defaultToSpeaker 播放預設走手機喇叭
        // 允許使用支援 HFP 的藍牙裝置作為麥克風輸入 allowBluetoothHFP
        try audioSession.setCategory(.playAndRecord,
                                     mode: .default,
                                     options: [
                                        .defaultToSpeaker,
                                        .allowBluetoothHFP
                                     ])
        try audioSession.setActive(true)
    }
    
    /// 判斷需不需要設置麥克風
    func isNeedSetRecorder() -> Bool {
        return recorder == nil
    }
    
    /// 麥克風相關設置
    func setRecorder(fileID: String, qualityType: SoundQuality) throws {
        if recorder == nil {
            let setting = RecorderHelper.share.recorderSetting(qualityType: qualityType)
            //設置麥克風
            recorder = try RecorderHelper.share.setRecorder(fileName: fileID, setting: setting)
        }
    }
    /// 錄音
    func record() {
        guard let recorder else { return }
        recorder.prepareToRecord()
        recorder.record()
    }
    
    /// 暫停
    func pause() {
        guard let recorder else { return }
        recorder.pause()
    }
    
    /// 停止（錄音結束）
    func stop() {
        guard let recorder else { return }
        recorder.stop()
    }
    
    /// 清除麥克風設置
    func clearRecorder() {
        recorder = nil
    }
    
    /// 取得錄音時間
    func getRecordCurrentTime() -> Double {
        return recorder?.currentTime ?? 0.0
    }
}
