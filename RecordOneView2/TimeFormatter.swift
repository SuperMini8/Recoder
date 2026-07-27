//
//  TimeFormatter.swift
//  Record_02
//
//  將秒數（duration）格式化為顯示字串
//

import Foundation

/// 轉換時間格式（使用enum -> 這是一組靜態工具、不該被 new 出來）
enum TimeFormatter {
    /// 將秒數格式化為 "HH:MM:SS"，例如 65 → "00:01:05"
    static func string(from seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d:%02d",
                      total / 3600, (total % 3600) / 60, total % 60)
    }
}
