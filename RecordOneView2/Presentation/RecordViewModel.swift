//
//  RecordViewModel.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import Foundation

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
    /// 正在選擇的檔案 ID
    private(set) var selectedRecordID: String?
    /// 正在選擇的檔案
    var selectedRecordData: RecordData? {
        guard let selectedRecordID else { return nil }
        return recordDatas.first { $0.recordID == selectedRecordID }
    }
    /// 正在選擇的檔案 index
    var selectedRecordIndex: Int? {
        guard let selectedRecordID else { return nil }
        return recordDatas.firstIndex { $0.recordID == selectedRecordID }
    }
    
    /// 取得錄音資料
    func loadRecords() {
        recordDatas = (try? repository.fetchRecords()) ?? []
    }
    /// 準備新的錄音檔
    func prepareNewRecording(id: String, qualityType: SoundQuality) {
        clearSelection()
        let record = repository.createRecord(id: id, qualityType: qualityType)
        currentRecordingData = record
        recordDatas.insert(record, at: 0)
    }
    /// 錄音完成，儲存
    func finishCurrentRecording(duration: Float) throws {
        guard let record = currentRecordingData else { return }
        repository.updateDuration(record, duration: duration)
        try repository.save()
        currentRecordingData = nil
    }
    /// 放棄正在錄音的檔案
    func discardCurrentRecording() throws {
        guard let record = currentRecordingData else { return }
        let recordID = record.recordID

        try repository.delete(record)
        recordDatas.removeAll { $0.recordID == recordID }
        currentRecordingData = nil
        // 正常流程應該無法點擊
        if selectedRecordID == recordID {
            clearSelection()
        }
    }
    /// 更新 Title
    func renameRecord(at index: Int, title: String) throws {
        guard recordDatas.indices.contains(index) else { return }
        let record = recordDatas[index]
        try repository.updateTitle(record, title: title)
    }
    /// 刪除錄音檔
    func deleteRecord(at index: Int) throws {
        guard recordDatas.indices.contains(index) else { return }
        let record = recordDatas[index]
        let isDeletingSelectedRecord = record.recordID == selectedRecordID
        let isDeletingCurrentRecording = record.recordID == currentRecordingData?.recordID
        
        try repository.delete(record)
        recordDatas.remove(at: index)

        if isDeletingSelectedRecord {
            clearSelection()
        }
        if isDeletingCurrentRecording {
            currentRecordingData = nil
        }
    }
    /// 記錄已選擇的檔案
    func selectRecord(at index: Int) {
        guard recordDatas.indices.contains(index) else { return }
        selectedRecordID = recordDatas[index].recordID
        viewState = .selectedData
    }
    /// 清除已選擇狀態
    func clearSelection() {
        selectedRecordID = nil
        viewState = .none
    }
}
