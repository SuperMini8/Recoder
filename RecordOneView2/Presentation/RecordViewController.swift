import UIKit

class RecordViewController: UIViewController {
    
    @IBOutlet weak var playTimeSlider: UISlider!  //播放進度條
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var timeLabel: UILabel!   //顯示時間的Label
    @IBOutlet weak var settingSegment: UISegmentedControl!   //音質按鈕
    @IBOutlet weak var recordButton: UIButton!    //錄音按鈕
    @IBOutlet weak var stopButton: UIButton!     //停止按鈕
    @IBOutlet weak var playButton: UIButton!    //播放按鈕
    @IBOutlet weak var editNameButton: UIButton!     //編輯名字按鈕
    private let ticker = Ticker()  //更新畫面用的計時器
    var playingTime : Float = 0
    
    private var viewModel = RecordViewModel()
    private var audioSessionService = AudioSessionService()
    private var recorderService = AudioRecorderService()
    private var playerService = AudioPlayerService()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setAudioSession()
        viewModel.loadRecords()
        setSegment()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        playerService.onFinishPlaying = { [weak self] in self?.handlePlayingFinished() }
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        render()
    }
    /// 系統設置
    private func setAudioSession() {
        guard audioSessionService.isRecordPermissionGranted else { return }

        do {
            try audioSessionService.setSession()
        } catch  {
            print("系統設置錯誤\(error)")
        }
    }
    
    /// 手動建立 Segment Items
    private func setSegment() {
        settingSegment.removeAllSegments()
        
        let segmentItems = SoundQuality.allCases.map(\.displayText)
        segmentItems.enumerated().forEach { index, title in
            settingSegment.insertSegment(withTitle: title, at: index, animated: false)
        }
        // 設定預設值
        settingSegment.selectedSegmentIndex = viewModel.qualityType.rawValue
    }
    // MARK: edit Delete
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.setEditing(editing, animated: true)
        if editing {
            viewModel.viewState = .editing
        } else {
            // 離開編輯，依是否仍有選取回到對應狀態
            viewModel.viewState = viewModel.selectedRecordData != nil ? .selectedData : .none
        }
        render()
    }
    
    // MARK: 錄音按鈕
    @IBAction func recorder(_ sender: UIButton) {
        // 點擊錄音才詢問權限
        audioSessionService.requestRecordPermission { [weak self] isPermission in
            guard let self else { return }
            guard isPermission else {
                self.present(AlertFactory.micNoPermission(), animated: true, completion: nil)
                return
            }

            do {
                try self.audioSessionService.setSession()
            } catch {
                print("系統設置錯誤\(error)")
                return
            }

            self.handleRecorderButtonTap()
        }
    }

    private func handleRecorderButtonTap() {
        if viewModel.viewState == .playing || viewModel.viewState == .playingPause {
            return
        }
        // 是否有需要設置麥克風
        if recorderService.isNeedSetRecorder() {
            // 設置麥克風
            do {
                //創造一個資料
                let uuid = UUID().uuidString
                try recorderService.setRecorder(fileID: uuid, qualityType: viewModel.qualityType)
                viewModel.prepareNewRecording(id: uuid, qualityType: viewModel.qualityType)
                // 畫面做加入的更新
                let indexPath = IndexPath(row: 0, section: 0)
                self.tableView.insertRows(at: [indexPath], with: .automatic)
            } catch  {
                print("麥克風設置失敗\(error)")
                return
            }
        }
        // 依狀態決定錄音 or 暫停
        switch viewModel.viewState {
        // 正在錄音（此時傳進來的為暫停）
        case .recording:
            viewModel.viewState = .recordingPause
            recorderService.pause()
            self.ticker.stop()
            render()
        // 其餘狀態（此時傳進來的為錄音）
        default:
            viewModel.viewState = .recording
            recorderService.record()
            self.playTimeSlider.value = 0
            if !self.ticker.isRunning {
                self.ticker.onTick = { [weak self] in self?.updatedTimeLabel() }
                self.ticker.start(interval: 0.1)
            }
            render()
        }
    }
    // MARK: 錄音時間
    private func updatedTimeLabel() {
        let recordTime = recorderService.getRecordCurrentTime()
        self.timeLabel.text = TimeFormatter.string(from: recordTime)
        
        guard let recordData = self.viewModel.currentRecordingData else { return }
        recordData.recordTime = Float(recordTime)
    }
    // MARK: 停止按鈕
    @IBAction func stop(_ sender: UIButton) {
        switch viewModel.viewState {
        case .recording,
             .recordingPause:
            viewModel.viewState = .none
            recorderService.stop()
            if let recordData = self.viewModel.currentRecordingData {
                do {
                    try viewModel.finishCurrentRecording(duration: recordData.recordTime)
                    let indexPath = IndexPath(row: 0, section: 0)
                    self.tableView.reloadRows(at:[indexPath] , with: .automatic)
                } catch {
                    do {
                        try viewModel.discardCurrentRecording()
                        let indexPath = IndexPath(row: 0, section: 0)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        // alert 提醒失敗
                        present(AlertFactory.make(title: "儲存失敗", message: error.localizedDescription), animated: true)
                    } catch {
                        print("清除未完成錄音失敗：\(error.localizedDescription)")
                        present(AlertFactory.make(title: "儲存失敗",
                                                  message: "錄音沒有成功儲存，且清除未完成錄音時發生錯誤：\(error.localizedDescription)"),
                                animated: true)
                    }
                }
            }
            recorderService.clearRecorder()
            self.ticker.stop()

        case .playing,
             .playingPause:
            // 停止播放後仍保有選取，回到 selectedData 讓狀態與 UI 一致
            viewModel.viewState = .selectedData
            playerService.stop()
            playerService.clearPlayer()
            self.playingTime = 0
            self.ticker.stop()
            if let selectedRecordData = viewModel.selectedRecordData {
                self.timeLabel.text = TimeFormatter.string(from: Double(selectedRecordData.recordTime))
                self.playTimeSlider.value = 0
            }

        default:
            return
        }
        render()
    }
    //MARK: 播放按鈕
    @IBAction func play(_ sender: UIButton) {
        // 先設置播放器
        if playerService.isNeedSetPlayer() {
            guard let selectedRecordData = viewModel.selectedRecordData else { return }
            do {
                try playerService.setPlayer(selectedRecordData)
            } catch {
                print("播放器設置失敗\(error)")
                return
            }
        }
        // 依狀態決定播放 or 暫停
        switch viewModel.viewState {
        // 正在播放（此時傳進來的為暫停）
        case .playing:
            viewModel.viewState = .playingPause
            playerService.pause()
            self.playingTime = 0
            self.ticker.stop()
            render()

        // 其餘狀態（此時傳進來的為播放）
        default:
            viewModel.viewState = .playing
            if self.playingTime != 0 {
                playerService.setPlayingCurrentTime(Double(self.playingTime))
            }
            playerService.play()
            self.playingTime = 0
            if !self.ticker.isRunning {
                self.ticker.onTick = { [weak self] in self?.updatePlayingTime() }
                self.ticker.start(interval: 0.01)
            }
            render()
        }
    }
    //MARK: 拖動進度條
    @IBAction func changePlayTime(_ sender: UISlider) {
        self.playingTime = self.playTimeSlider.value
        playerService.setPlayingCurrentTime(Double(playingTime))
        self.timeLabel.text = TimeFormatter.string(from: Double(playingTime))
    }
    // MARK: 播放時間（Ticker 每次觸發，只負責更新進度）
    private func updatePlayingTime() {
        let playTime = playerService.getPlayingCurrentTime()
        self.timeLabel.text = TimeFormatter.string(from: playTime)
        self.playTimeSlider.value = Float(playTime)
    }
    // MARK: 播放自然結束（由 AVAudioPlayerDelegate 事件觸發）
    private func handlePlayingFinished() {
        viewModel.viewState = .selectedData
        playerService.clearPlayer()
        self.playingTime = 0
        self.ticker.stop()     //計時器停止
        render()
    }
    // MARK: 編輯名字
    @IBAction func editName(_ sender: Any) {
        if let selectedRecordData = viewModel.selectedRecordData,
           let selectedIndex = viewModel.selectedRecordIndex {
            let alert = AlertFactory.renameRecord(currentTitle: selectedRecordData.title) { [weak self] text in
                guard let self else { return }
                do {
                    try self.viewModel.renameRecord(at: selectedIndex, title: text)
                    self.tableView.reloadRows(at: [IndexPath(row: selectedIndex, section: 0)], with: .automatic)
                } catch {
                    print("命名儲存失敗：\(error.localizedDescription)")
                }
                // 改名後取消選取，必須重選才能操作
                self.viewModel.clearSelection()
                self.render()
            }
            present(alert, animated: true, completion: nil)
        }
    }
    //MARK: 換音質
    @IBAction func changeSetting(_ sender: UISegmentedControl) {
        guard let type = SoundQuality(rawValue: sender.selectedSegmentIndex) else { return }
        viewModel.qualityType = type
    }
    //MARK: 離開畫面的時候
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 如果還有未儲存的錄音
        guard viewModel.viewState == .recording || viewModel.viewState == .recordingPause
        else { return }
        viewModel.viewState = .none
        recorderService.stop()
        if let recordData = self.viewModel.currentRecordingData {
            do {
                try viewModel.finishCurrentRecording(duration: recordData.recordTime)
            } catch {
                // viewWillDisappear 不 show alert 純 print
                print("儲存失敗：\(error.localizedDescription)")
                do {
                    try viewModel.discardCurrentRecording()
                } catch {
                    print("清除未完成錄音失敗：\(error.localizedDescription)")
                }
            }
        }
        recorderService.clearRecorder()
        self.ticker.stop()
    }

    //MARK: 傳送檔案
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBAction func share(_ sender: UIBarButtonItem) {
        if let selectedData = viewModel.selectedRecordData,
            let fileURL = try? selectedData.fileURL() {
            let share = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = sender
            present(share, animated: true, completion: nil)
            
        }
    }
    /// 依 viewModel.viewState 統一套用所有控制項的啟用狀態與外觀
    private func render() {
        let state = viewModel.viewState.controlState
        recordButton.isEnabled = state.record
        stopButton.isEnabled = state.stop
        playButton.isEnabled = state.play
        settingSegment.isEnabled = state.segment
        editButtonItem.isEnabled = state.edit
        editNameButton.isEnabled = state.editName
        shareButton.isEnabled = state.share
        playTimeSlider.isEnabled = state.slider
        tableView.isUserInteractionEnabled = state.tableInteraction

        recordButton.setBackgroundImage(UIImage(systemName: state.recordImage), for: .normal)
        playButton.setBackgroundImage(UIImage(systemName: state.playImage), for: .normal)
        editButtonItem.title = state.editTitle
    }
}

extension RecordViewController: UITableViewDataSource, UITableViewDelegate {
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.viewModel.recordDatas.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let recordData = self.viewModel.recordDatas[indexPath.row]
        cell.textLabel?.text = recordData.title
        cell.detailTextLabel?.text = TimeFormatter.string(from: Double(recordData.recordTime))
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let alert = AlertFactory.make(title: "確定要刪除嗎？",
                                      message: "刪除後將無法復原",
                                      preferredStyle: .actionSheet,
                                      action1Title: "刪除",
                                      action1Style: .destructive,
                                      action1Handler: { [weak self] _ in
            guard let self = self else { return }
            do {
                try self.viewModel.deleteRecord(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                print("刪除失敗：\(error.localizedDescription)")
            }
            // 仍在編輯模式則維持 editing，否則依是否還有選取決定狀態
            if self.isEditing {
                self.viewModel.viewState = .editing
            } else {
                self.viewModel.viewState = self.viewModel.selectedRecordData != nil ? .selectedData : .none
            }
            if self.viewModel.selectedRecordData == nil {
                self.timeLabel.text = TimeFormatter.string(from: 0)
            }
            self.render()
        },
                                      action2Title: "取消",
                                      action2Style: .cancel,
                                      sourceView: view
        )
        present(alert, animated: true)
    }
    // MARK: 選擇row
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard viewModel.viewState == .none || viewModel.viewState == .selectedData  else { return }
        viewModel.selectRecord(at: indexPath.row)
        guard let selectedData = viewModel.selectedRecordData else { return }
        settingSegment.selectedSegmentIndex = selectedData.qualityType
        playTimeSlider.maximumValue = Float(selectedData.recordTime)
        playTimeSlider.value = 0
        self.timeLabel.text = TimeFormatter.string(from: Double(selectedData.recordTime))
        render()
    }

    
}
