import UIKit
import AVFoundation
import CoreData

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
        self.playTimeSlider.isEnabled = false
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        self.editButtonItem.title = "編輯"
    }
    /// 系統設置
    private func setAudioSession() {
        recorderService.checkRecordPermission { [weak self] isPermission in
            if isPermission {
                do {
                    try self?.recorderService.setSession()
                } catch  {
                    print("系統設置錯誤\(error)")
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.present(RecorderHelper.share.micNoPermission(), animated: true, completion: nil)
                }
            }
        }
    }
    
    /// 手動建立 Segment Items
    private func setSegment() {
        settingSegment.removeAllSegments()
        
        let segmentItems = SoundQuality.allCases.map(\.displayText)
        segmentItems.enumerated().forEach { index, title in
            settingSegment.insertSegment(withTitle: title, at: index, animated: false)
        }
    }
    // MARK: edit Delete
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.setEditing(editing, animated: true)
        if self.tableView.isEditing {
            self.playTimeSlider.isEnabled = false
            self.editNameButton.isEnabled = false
            self.shareButton.isEnabled = false
            self.recordButton.isEnabled = false
            self.playButton.isEnabled = false
            self.editButtonItem.title = "完成"
            print("要刪除")
        }else {
            self.recordButton.isEnabled = true
            print("已完成")
            self.editButtonItem.title = "編輯"
        }
    }
    
    // MARK: 錄音按鈕
    @IBAction func recorder(_ sender: UIButton) {
        // 檢查授權
        guard let isPermission = recorderService.checkRecordPermission(), isPermission else {
            self.present(RecorderHelper.share.micNoPermission(), animated: true, completion: nil)
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
            self.recordButton.setBackgroundImage( UIImage(systemName: "record.circle"), for: .normal)  //暫停時，按鈕改成在錄音鍵
        // 其餘狀態（此時傳進來的為錄音）
        default:
            viewModel.viewState = .recording
            recorderService.record()
            self.recordButton.setBackgroundImage(UIImage(systemName: "pause.circle"), for: .normal)   //錄音時，按鈕改成暫停鍵
            if !self.ticker.isRunning {
                self.ticker.onTick = { [weak self] in self?.updatedTimeLabel() }
                self.ticker.start(interval: 0.1)
            }
            isRecordingAboutButton()
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
                        showAlert(title: "儲存失敗", message: error.localizedDescription)
                    } catch {
                        print("清除未完成錄音失敗：\(error.localizedDescription)")
                        showAlert(title: "儲存失敗", message: "錄音沒有成功儲存，且清除未完成錄音時發生錯誤：\(error.localizedDescription)")
                    }
                }
            }
            recorderService.clearRecorder()
            // 就算儲存失敗，也要更新 UI
            self.recordButton.setBackgroundImage(UIImage(systemName: "circle.inset.filled"), for: .normal)
            self.ticker.stop()

        case .playing,
             .playingPause:
            viewModel.viewState = .none
            playerService.stop()
            playerService.clearPlayer()
            self.playingTime = 0
            self.ticker.stop()
            self.playButton.setBackgroundImage(UIImage(systemName: "play.circle"), for: .normal)
            if let selectedRecordData = viewModel.selectedRecordData {
                self.timeLabel.text = TimeFormatter.string(from: Double(selectedRecordData.recordTime))
                self.playTimeSlider.value = 0
            }
            
        default:
            return
        }
        allStopAboutButton()
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
            //暫停時，將按鈕改成再播放鍵
            self.playButton.setBackgroundImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            
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
            //播放中，按鈕改成暫停鍵
            self.playButton.setBackgroundImage(UIImage(systemName: "pause.circle"), for: .normal)
            isPlayingAboutButton()
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
        //播放鍵變回一般的
        self.playButton.setBackgroundImage(UIImage(systemName: "play.circle"), for: .normal)
        allStopAboutButton()
        self.playingTime = 0
        self.ticker.stop()     //計時器停止
    }
    // MARK: 編輯名字
    @IBAction func editName(_ sender: Any) {
        if let selectedRecordData = viewModel.selectedRecordData,
           let selectedIndex = viewModel.selectedRecordIndex {
            //使用alert來改名
            let alert = UIAlertController(title: "請輸入標題", message: nil, preferredStyle: .alert)
            let ok = UIAlertAction(title: "確定", style: .default) { [weak self] _ in
                guard let text = alert.textFields![0].text else { return }
                self?.playButton.isEnabled = false   // 編輯結束，必須重選，按鈕才能按
                self?.editNameButton.isEnabled = false
                self?.playTimeSlider.isEnabled = false
                do {
                    try self?.viewModel.renameRecord(at: selectedIndex, title: text)
                    self?.tableView.reloadRows(at: [IndexPath(row: selectedIndex, section: 0)], with: .automatic)
                } catch {
                    print("命名儲存失敗：\(error.localizedDescription)")
                }
            }
            let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            alert.addTextField(configurationHandler: { textField in
                textField.text = selectedRecordData.title
            })
            alert.addAction(ok)
            alert.addAction(cancel)
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
            present(share, animated: true, completion: nil)
            
        }
    }
    //錄音時的按鈕設置
    func isRecordingAboutButton() {
        stopButton.isEnabled = true  //需要停止鍵來停止
        playButton.isEnabled = false //錄音放，不給播放
        settingSegment.isEnabled = false  //錄音中不給改音質
        editButtonItem.isEnabled = false  //不可以刪檔，在錄音的時候
        editNameButton.isEnabled = false
        shareButton.isEnabled = false
        tableView.isUserInteractionEnabled = false
        tableView.isEditing = false
        playTimeSlider.isEnabled = false
        playTimeSlider.value = 0
    }
    //開始播放時的按鈕設置
    func isPlayingAboutButton() {
        recordButton.isEnabled = false
        stopButton.isEnabled = true
        settingSegment.isEnabled = false
        editButtonItem.isEnabled = false
        editNameButton.isEnabled = false
        shareButton.isEnabled = false
        tableView.isUserInteractionEnabled = false
    }
    //按下停止鍵時的按鈕設置
    func allStopAboutButton() {
        recordButton.isEnabled = true
        stopButton.isEnabled = false
        settingSegment.isEnabled = true
        editButtonItem.isEnabled = true
        tableView.isUserInteractionEnabled = true
    }
    //點選row時的按鈕設置
    func selectedRowAboutButton() {
        playButton.isEnabled = true
        editNameButton.isEnabled = true
        shareButton.isEnabled = true
        playTimeSlider.isEnabled = true
        playTimeSlider.value = 0
    }
    
    /// 顯示 alert
    func showAlert(title: String?,
                   message: String?,
                   alertStyle: UIAlertController.Style = .alert,
                   action1Title: String? = nil,
                   action1Style: UIAlertAction.Style = .default,
                   action1Handler: ((UIAlertAction) -> Void)? = nil,
                   action2Title: String? = nil,
                   action2Style: UIAlertAction.Style = .default,
                   action2Handler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: alertStyle)
        let action1 = UIAlertAction(title: action1Title ?? "確認", style: action1Style, handler: action1Handler)
        alert.addAction(action1)
        if action2Title != nil {
            let action2 = UIAlertAction(title: action2Title, style: action2Style, handler: action2Handler)
            alert.addAction(action2)
        }
        DispatchQueue.main.async { [weak self] in
            self?.present(alert, animated: true)
        }
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
        showAlert(title: "確定要刪除嗎？",
                  message: "刪除後將無法復原",
                  alertStyle: .actionSheet,
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
            self.timeLabel.text = TimeFormatter.string(from: 0)
            self.editNameButton.isEnabled = false
            self.playButton.isEnabled = false
            self.stopButton.isEnabled = false
            self.shareButton.isEnabled = false
        },
                  action2Title: "取消",
                  action2Style: .cancel
        )
    }
    // MARK: 選擇row
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard viewModel.viewState == .none || viewModel.viewState == .selectedData  else { return }
        viewModel.selectRecord(at: indexPath.row)
        guard let selectedData = viewModel.selectedRecordData else { return }
        settingSegment.selectedSegmentIndex = selectedData.qualityType
        selectedRowAboutButton()
        playTimeSlider.maximumValue = Float(selectedData.recordTime)
        self.timeLabel.text = TimeFormatter.string(from: Double(selectedData.recordTime))
    }

    
}
