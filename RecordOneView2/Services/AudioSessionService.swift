//
//  AudioSessionService.swift
//  Record_02
//
//  Handles microphone permission and shared audio session setup.
//

import AVFoundation

final class AudioSessionService {

    var isRecordPermissionGranted: Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVAudioSession.sharedInstance().recordPermission == .granted
        }
    }

    /// 檢查麥克風權限；如果還沒決定，會先跳系統授權再回傳結果。
    func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        let completeOnMain: (Bool) -> Void = { isAgree in
            DispatchQueue.main.async {
                completion(isAgree)
            }
        }

        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .undetermined:
                AVAudioApplication.requestRecordPermission { isAgree in
                    completeOnMain(isAgree)
                }
            case .denied:
                completeOnMain(false)
            case .granted:
                completeOnMain(true)
            @unknown default:
                completeOnMain(false)
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { isAgree in
                    completeOnMain(isAgree)
                }
            case .denied:
                completeOnMain(false)
            case .granted:
                completeOnMain(true)
            @unknown default:
                completeOnMain(false)
            }
        }
    }

    /// 系統相關設置
    func setSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        // 錄音與播放共用 playAndRecord；defaultToSpeaker 讓播放預設走喇叭。
        try audioSession.setCategory(.playAndRecord,
                                     mode: .default,
                                     options: [
                                        .defaultToSpeaker,
                                        .allowBluetoothHFP
                                     ])
        try audioSession.setActive(true)
    }
}
