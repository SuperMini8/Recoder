//
//  RecordControlState.swift
//  Record_02
//
//  Converts domain state into view control state.
//

import Foundation

/// 由 viewState 推導出的各控制項狀態（單一真相來源，避免散落的 .isEnabled 漂移）
struct RecordControlState {
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

extension RecordViewState {
    /// 只定義「可以」使用的項目
    var controlState: RecordControlState {
        switch self {
        case .none:
            return RecordControlState(record: true, segment: true, edit: true, tableInteraction: true)
        case .selectedData:
            return RecordControlState(record: true, play: true, segment: true, edit: true,
                                      editName: true, share: true, slider: true, tableInteraction: true)
        case .recording:
            return RecordControlState(record: true, stop: true, recordImage: "pause.circle")
        case .recordingPause:
            return RecordControlState(record: true, stop: true, recordImage: "record.circle")
        case .playing:
            return RecordControlState(stop: true, play: true, slider: true, playImage: "pause.circle")
        case .playingPause:
            return RecordControlState(stop: true, play: true, slider: true, playImage: "play.circle.fill")
        case .editing:
            return RecordControlState(edit: true, tableInteraction: true, editTitle: "完成")
        }
    }
}
