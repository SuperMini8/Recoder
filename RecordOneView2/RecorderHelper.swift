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
    
    func recorderSetting (formatIDKey: AudioFormatID, sampleRateKey: Int, encoderAudioQualityKey: Int, numberOfChannelsKey: Int, linearPCMBitDepthKey: Int, encoderBitRateKey: Int) -> [String: Any] {
        let recordSetting : [String:Any] = [
            AVFormatIDKey : NSNumber(value : formatIDKey),   //儲存的格式
            AVSampleRateKey : NSNumber(value: sampleRateKey),      //每秒的錄音採樣率
            AVEncoderAudioQualityKey : NSNumber(value: encoderAudioQualityKey),   //錄音音質
            AVNumberOfChannelsKey : NSNumber(value: numberOfChannelsKey),  //聲道
            AVLinearPCMBitDepthKey : NSNumber(value: linearPCMBitDepthKey),  //採樣深度
            AVEncoderBitRateKey : NSNumber(value: encoderBitRateKey)]
        return recordSetting
    }
    //設定麥克風
    func setRecorder(fileName: String, setting: [String: Any]) throws -> AVAudioRecorder {
        //給檔案名，製作URL
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docURL.appendingPathComponent("\(fileName).wav")
        var recorder = AVAudioRecorder()
        recorder = try AVAudioRecorder(url: url, settings: setting)
        return recorder
    }
    //未授權麥克風狀況的alert
    func micNoPermission() -> UIAlertController {
        let alert = UIAlertController(title: "麥克風權限受限", message: "必須要授權麥克風才能錄音", preferredStyle: .alert)
        let ok = UIAlertAction(title: "設置", style: .destructive) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else{return}
            if UIApplication.shared.canOpenURL(url){
                UIApplication.shared.open(url, completionHandler: nil)
            }
        }
        let cancel = UIAlertAction(title: "拒絕", style: .cancel, handler: nil)
        alert.addAction(ok)
        alert.addAction(cancel)
        return alert
    }
    
    
}
