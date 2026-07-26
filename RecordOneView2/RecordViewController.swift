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
    var docURL : URL = URL(fileURLWithPath: NSHomeDirectory().appending("/Documents"))
    var player : AVAudioPlayer?       //播放器
    var recordSetting : [String:Any] = RecorderHelper.share.recorderSetting(qualityType: .low)
    var timer : Timer?  //更新畫面用的計時器
    var indexPath : IndexPath?  //記錄點選的位置
    var playingTime : Float = 0
    
    private var viewModel = RecordViewModel()
    private var recorderService = AudioRecorderService()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setAudioSession()
        viewModel.loadRecords()
        setSegment()
        self.tableView.dataSource = self
        self.tableView.delegate = self
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
            self.timer?.invalidate()
            self.timer = nil
            self.recordButton.setBackgroundImage( UIImage(systemName: "record.circle"), for: .normal)  //暫停時，按鈕改成在錄音鍵
        // 其餘狀態（此時傳進來的為錄音）
        default:
            viewModel.viewState = .recording
            recorderService.record()
            self.recordButton.setBackgroundImage(UIImage(systemName: "pause.circle"), for: .normal)   //錄音時，按鈕改成暫停鍵
            if self.timer == nil {
                self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updatedTimeLabel), userInfo: nil, repeats: true)
            }
            isRecordingAboutButton()
        }
    }
    // MARK: 錄音時間
    @objc func updatedTimeLabel() {
        let recordTime = recorderService.getRecordCurrentTime()
        self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (Int(recordTime)/60)/60,(Int(recordTime)/60)%60,Int(recordTime)%60) as String
        
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
                    try viewModel.finishRecording(duration: recordData.recordTime)
                    let indexPath = IndexPath(row: 0, section: 0)
                    self.tableView.reloadRows(at:[indexPath] , with: .automatic)
                } catch {
                    print("儲存失敗：\(error.localizedDescription)")
                    // alert 提醒失敗
                    showAlert(title: "儲存失敗", message: error.localizedDescription)
                    // 把畫面已經出現的檔案刪除(可能檔案不在，沒刪除成功也不用管 error）
                    try? viewModel.deleteRecord(at: 0)
                }
            }
            recorderService.clearRecorder()
            // 就算儲存失敗，也要更新 UI
            self.recordButton.setBackgroundImage(UIImage(systemName: "circle.inset.filled"), for: .normal)
            self.timer?.invalidate()
            self.timer = nil
            
        case .playing,
             .playingPause:
            viewModel.viewState = .none
            if let player = self.player {
                player.stop()
                self.playingTime = 0
                self.timer?.invalidate()
                self.timer = nil
                self.playButton.setBackgroundImage(UIImage(systemName: "play.circle"), for: .normal)
                self.player = nil
                if let indexPath = self.indexPath{
                    let recordData = self.viewModel.recordDatas[indexPath.row]
                    self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (Int(recordData.recordTime)/60)/60,(Int(recordData.recordTime)/60)%60,Int(recordData.recordTime)%60) as String
                    self.playTimeSlider.value = 0
                }
            }
            
        default:
            return
        }
        allStopAboutButton()
    }
    //MARK: 播放按鈕
    @IBAction func play(_ sender: UIButton) {
        if self.player == nil {    //先設置麥克風
            do {
                if let indexPath = self.indexPath {
                    let recordData = self.viewModel.recordDatas[indexPath.row]    //取出位置中的檔案
                    let recordURL = self.docURL.appendingPathComponent("\(recordData.recordID).wav")
                    self.player = try AVAudioPlayer(contentsOf: recordURL)
                }
            } catch  {
                print("麥克風設置失敗\(error)")
            }
        }
        if let player = self.player {
            if player.isPlaying{   //判斷是否正在播放
                viewModel.viewState = .playingPause
                player.pause()
                self.playingTime = 0
                print("播放暫停")
                self.timer?.invalidate()
                self.timer = nil
                self.playButton.setBackgroundImage(UIImage(systemName: "play.circle.fill"), for: .normal)  //暫停時，將按鈕改成再播放鍵
            }else{
                if self.playingTime != 0 {
                    player.currentTime = Double(self.playingTime)
                }
                viewModel.viewState = .playing
                player.play()
                self.playingTime = 0
                print("播放開始")
                if self.timer == nil {
                self.timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(playTime), userInfo: nil, repeats: true)
                }
                self.playButton.setBackgroundImage(UIImage(systemName: "pause.circle"), for: .normal) //播放中，按鈕改成暫停鍵
                isPlayingAboutButton()
            }
        }
    }
    //MARK: 拖動進度條
    @IBAction func changePlayTime(_ sender: UISlider) {
        self.playingTime = self.playTimeSlider.value
        let changeTime = Int(playingTime)
        if let player = self.player {
            player.currentTime = Double(playingTime)
        }
        self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (changeTime/60)/60,(changeTime/60)%60,changeTime%60) as String
    }
    //MARK: 播放時間
    @objc func playTime () {
        if let player = self.player {
            if player.isPlaying{ //如果正在播放
                let playTime = Int(player.currentTime)  //就更新時間
                self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (playTime/60)/60,(playTime/60)%60,playTime%60) as String
                self.playTimeSlider.value = Float(player.currentTime)
            } else  {
            //播放結束
                self.playButton.setBackgroundImage(UIImage(systemName: "play.circle"), for: .normal)  //播放鍵變回一般的
                allStopAboutButton()
                self.playingTime = 0
                self.timer?.invalidate()     //計時器停止
                self.timer = nil
                self.player = nil
                viewModel.viewState = .none
            }
        }
    }
    // MARK: 編輯名字
    @IBAction func editName(_ sender: Any) {
        if let indexPath = self.indexPath {
            //使用alert來改名
            let alert = UIAlertController(title: "請輸入標題", message: nil, preferredStyle: .alert)
            let ok = UIAlertAction(title: "確定", style: .default) { [weak self] _ in
                guard let text = alert.textFields![0].text else { return }
                self?.playButton.isEnabled = false   // 編輯結束，必須重選，按鈕才能按
                self?.editNameButton.isEnabled = false
                self?.playTimeSlider.isEnabled = false
                do {
                    try self?.viewModel.renameRecord(at: indexPath.row, title: text)
                    self?.tableView.reloadRows(at: [indexPath], with: .automatic)
                } catch {
                    print("命名儲存失敗：\(error.localizedDescription)")
                }
            }
            let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            let recordData = self.viewModel.recordDatas[indexPath.row]    //取出位置中的檔案
            alert.addTextField(configurationHandler: { textField in
                textField.text = recordData.title
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
        recordSetting = RecorderHelper.share.recorderSetting(qualityType: viewModel.qualityType)
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
                try viewModel.finishRecording(duration: recordData.recordTime)
                let indexPath = IndexPath(row: 0, section: 0)
                self.tableView.reloadRows(at:[indexPath] , with: .automatic)
            } catch {
                print("儲存失敗：\(error.localizedDescription)")
                // alert 提醒失敗
                showAlert(title: "儲存失敗", message: error.localizedDescription)
                // 把畫面已經出現的檔案刪除(可能檔案不在，沒刪除成功也不用管 error）
                try? viewModel.deleteRecord(at: 0)
            }
        }
        recorderService.clearRecorder()
        self.timer?.invalidate()
        self.timer = nil
    }
    
    //MARK: 傳送檔案
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBAction func share(_ sender: UIBarButtonItem) {
        if let indexPath = self.indexPath {
            let recordData = self.viewModel.recordDatas[indexPath.row]     //取出位置中的檔案
                let recordURL = self.docURL.appendingPathComponent("\(recordData.recordID).wav")
                let share = UIActivityViewController(activityItems: [recordURL], applicationActivities: nil)
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
    func showAlert(title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "確認", style: .default)
        alert.addAction(okAction)
        present(alert, animated: true)
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
        cell.detailTextLabel?.text = NSString(format: "%02d:%02d:%02d", (Int(recordData.recordTime)/60)/60,(Int(recordData.recordTime)/60)%60,Int(recordData.recordTime)%60) as String
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "確定要刪除嗎？", message: "刪除後將無法復原", preferredStyle: .actionSheet)
        let ok = UIAlertAction(title: "刪除", style: .destructive) {[weak self] _ in
            guard let self = self else { return }
            do {
                try self.viewModel.deleteRecord(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                print("刪除失敗：\(error.localizedDescription)")
            }
            self.timeLabel.text = NSString(format: "%02d:%02d:%02d", 0,0,0) as String
            self.editNameButton.isEnabled = false
            self.playButton.isEnabled = false
            self.stopButton.isEnabled = false
            self.shareButton.isEnabled = false
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(ok)
        alert.addAction(cancel)
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }
    //MARK: 選擇row
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.player == nil {
            self.indexPath = indexPath
            let recordData = self.viewModel.recordDatas[indexPath.row]
            self.settingSegment.selectedSegmentIndex = recordData.qualityType
            selectedRowAboutButton()
            self.playTimeSlider.maximumValue = Float(recordData.recordTime)
            self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (Int(recordData.recordTime)/60)/60,(Int(recordData.recordTime)/60)%60,Int(recordData.recordTime)%60) as String
            print("\(indexPath)")
        }
    }

    
}
