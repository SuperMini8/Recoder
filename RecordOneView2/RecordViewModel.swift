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

/// 由 viewState 推導出的各控制項狀態（單一真相來源，避免散落的 .isEnabled 漂移）
struct ControlState {
    var record = false
    var stop = false
    var play = false
    var segment = false
    var edit = false
    var editName = false
    var share = false
    var slider = false
    var tableInteraction = false

    var recordImage = "circle.inset.filled"
    var playImage = "play.circle"
    var editTitle = "編輯"
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
    /// 依目前 viewState 推導所有控制項該有的狀態
    var controlState: ControlState {
        switch viewState {
        case .none:
            return ControlState(record: true, segment: true, edit: true, tableInteraction: true)
        case .selectedData:
            return ControlState(record: true, play: true, segment: true, edit: true,
                                editName: true, share: true, slider: true, tableInteraction: true)
        case .recording:
            return ControlState(record: true, stop: true, recordImage: "pause.circle")
        case .recordingPause:
            return ControlState(record: true, stop: true, recordImage: "record.circle")
        case .playing:
            return ControlState(stop: true, play: true, slider: true, playImage: "pause.circle")
        case .playingPause:
            return ControlState(stop: true, play: true, slider: true, playImage: "play.circle.fill")
        case .editing:
            return ControlState(edit: true, tableInteraction: true, editTitle: "完成")
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
