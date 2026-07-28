//
//  AudioRecorderService.swift
//  Record_02
//
//  Created by 小八 on 2026/7/26.
//

import AVFoundation

final class AudioRecorderService {

    private var recorder : AVAudioRecorder?
    private let fileStore: RecordingFileStore

    init(fileStore: RecordingFileStore = .shared) {
        self.fileStore = fileStore
    }

    /// 判斷需不需要設置麥克風
    func isNeedSetRecorder() -> Bool {
        return recorder == nil
    }

    /// 麥克風相關設置
    func setRecorder(fileID: String, qualityType: SoundQuality) throws {
        if recorder == nil {
            let recordDataURL = try fileStore.fileURL(for: fileID, createDirectory: true)
            recorder = try AVAudioRecorder(url: recordDataURL, settings: qualityType.recorderSettings)
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
