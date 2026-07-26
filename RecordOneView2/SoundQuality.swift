//
//  SoundQuality.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import AVFoundation
import UIKit

enum SoundQuality: Int, CaseIterable {
    case low = 0
    case medium
    case high
    
    /// 顯示文字
    var displayText: String {
        switch self {
        case .low:
            return "低音質"
        case .medium:
            return "中音質"
        case .high:
            return "高音質"
        }
    }
    
    /// 儲存的格式
    var audioFormatID: AudioFormatID {
        switch self {
        case  .low:
            return kAudioFormatLinearPCM
        case  .medium:
            return kAudioFormatLinearPCM
        case  .high:
            return kAudioFormatLinearPCM
        }
    }
    
    /// 每秒的錄音採樣率
    var sampleRate: Double {
        switch self {
        case .low:
            return 16_000.0
        case .medium:
            return 30_000.0
        case .high:
            return 44_100.0
        }
    }
    
    /// 錄音音質
    var encoderAudioQuality: AVAudioQuality {
        switch self {
        case .low:
            return .medium
        case .medium:
            return .high
        case .high:
            return .max
        }
    }
    
    /// 聲道數
    /// 1：適合：人聲、語音備忘錄、訪談、語音辨識（檔案也比較小）
    /// 2：適合：音樂、環境音、外接立體聲麥克風（單純人聲通常沒有必要使用）
    var numberOfChannels: Int {
        switch self {
        case .low:
            return 1
        case .medium:
            return 1
        case .high:
            return 1
        }
    }
    
    /// 若使用 WAV／PCM，還需要設定
    /// 採樣深度
    var linearPCMBitDepth: Int {
        switch self {
        case .low:
            return 16
        case .medium:
            return 24
        case .high:
            return 32
        }
    }
    
    /// AAC 每秒使用多少 bit
    var encoderBitRate: Int {
        switch self {
        case .low:
            return 64_000
        case .medium:
            return 96_000
        case .high:
            return 128_000
        }
    }
    
}
