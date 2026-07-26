//
//  RecordViewModel.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import Foundation
import CoreData

/// 畫面狀態
enum RecordViewState {
    /// 沒有狀態
    case none
    /// 有選擇檔案
    case selectedData
    /// 正在錄音
    case recording
    /// 正在錄音時按暫停
    case recordingPause
    /// 正在播放
    case playing
    /// 正在播放時按暫停
    case playingPause
    /// 正在編輯
    case editing
}

final class RecordViewModel {
    private let repository = RecordRepository()
    
    /// 預設音質為低
    var qualityType: SoundQuality = .low
    /// 畫面狀態
    var viewState: RecordViewState = .none
    /// 錄音資料
    private(set) var recordDatas: [RecordData] = []
    /// 正在錄音的檔案
    private(set) var currentRecordingData: RecordData?
    
    /// 取得錄音資料
    func loadRecords() {
        recordDatas = (try? repository.fetchRecords()) ?? []
    }
    /// 準備新的錄音檔
    func prepareNewRecording(id: String, qualityType: SoundQuality) {
        let record = repository.createRecord(id: id, qualityType: qualityType)
        currentRecordingData = record
        recordDatas.insert(record, at: 0)
    }
    /// 錄音完成，儲存
    func finishRecording(duration: Float) throws {
        guard let record = currentRecordingData else { return }
        repository.updateDuration(record, duration: duration)
        try repository.save()
        currentRecordingData = nil
    }
    /// 更新 Title
    func renameRecord(at index: Int, title: String) throws {
        let record = recordDatas[index]
        try repository.updateTitle(record, title: title)
    }
    /// 刪除錄音檔
    func deleteRecord(at index: Int) throws {
        let record = recordDatas[index]
        try repository.delete(record)
        recordDatas.remove(at: index)
    }
    /// 取得「編輯按鈕」的顯示文字
    func getEditButtonText() -> String {
        return (viewState == .editing) ? "完成" : "編輯"
    }
    /// 取得「錄音按鈕」的顯示圖片
    func getRecorderButtonImage() -> String {
        return (viewState == .recording) ? "pause.circle" : "record.circle"
    }
    /// 取得「播放按鈕」的顯示圖片
    func getPlayerButtonImage() -> String {
        return (viewState == .playing) ? "pause.circle" : "play.circle.fill"
    }
    
    
}
