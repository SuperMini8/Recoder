//
//  RecorderHelper.swift
//  Record_02
//
//  Created by 小八 on 2022/4/6.
//

import Foundation
import AVFoundation
import UIKit
 
class RecorderHelper {
    private init () {}
    static let share = RecorderHelper()
    
    /// 設定錄音
    func recorderSetting (qualityType: SoundQuality) -> [String: Any] {
        let recordSetting: [String:Any] = [
            // 儲存的格式
            AVFormatIDKey: qualityType.audioFormatID,
            // 每秒的錄音採樣率
            AVSampleRateKey: NSNumber(value: qualityType.sampleRate),
            // 錄音音質
            AVEncoderAudioQualityKey: qualityType.encoderAudioQuality.rawValue,
            // 聲道
            AVNumberOfChannelsKey: qualityType.numberOfChannels,
            // 採樣深度
            AVLinearPCMBitDepthKey: qualityType.linearPCMBitDepth,
            // AAC 每秒使用多少 bit
            AVEncoderBitRateKey: qualityType.encoderBitRate
        ]
        return recordSetting
    }
    
    /// 設定麥克風
    func setRecorder(fileName: String, setting: [String: Any]) throws -> AVAudioRecorder {
        // 給檔案名，製作URL
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docURL.appendingPathComponent("\(fileName).wav")
        var recorder = AVAudioRecorder()
        recorder = try AVAudioRecorder(url: url, settings: setting)
        return recorder
    }
    
    /// 未授權麥克風狀況的alert
    func micNoPermission() -> UIAlertController {
        let alert = UIAlertController(title: "麥克風權限受限", message: "必須要授權麥克風才能錄音", preferredStyle: .alert)
        let ok = UIAlertAction(title: "設置", style: .destructive) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }
        let cancel = UIAlertAction(title: "拒絕", style: .cancel, handler: nil)
        alert.addAction(ok)
        alert.addAction(cancel)
        return alert
    }
    
    
}
