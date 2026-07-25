import UIKit
import AVFoundation
import CoreData

class RecordViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var playTimeSlider: UISlider!  //播放進度條
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var timeLabel: UILabel!   //顯示時間的Label
    @IBOutlet weak var settingSegment: UISegmentedControl!   //音質按鈕
    @IBOutlet weak var recordButton: UIButton!    //錄音按鈕
    @IBOutlet weak var stopButton: UIButton!     //停止按鈕
    @IBOutlet weak var playButton: UIButton!    //播放按鈕
    @IBOutlet weak var editNameButton: UIButton!     //編輯名字按鈕
    var docURL : URL = URL(fileURLWithPath: NSHomeDirectory().appending("/Documents"))
    var recordSession = AVAudioSession.sharedInstance()     //麥克風授權
    var recorderHasMic : Bool = false    //寄放使用者是否有授權的
    var recorder : AVAudioRecorder?    //錄音器
    var player : AVAudioPlayer?       //播放器
    var recordSetting : [String:Any] = RecorderHelper.share.recorderSetting(formatIDKey: kAudioFormatLinearPCM, sampleRateKey: 16000, encoderAudioQualityKey: AVAudioQuality.medium.rawValue, numberOfChannelsKey: 1, linearPCMBitDepthKey: 16, encoderBitRateKey: 128000)
    var timer : Timer?  //更新畫面用的計時器
    var indexPath : IndexPath?  //記錄點選的位置
    var data : [RecordData] = []
    var playingTime : Float = 0
    let moc = CoreDataHelper.shared.managedObjectContext()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //先設置麥克風的權限
        do {
            try recordSession.setCategory(AVAudioSession.Category.playAndRecord)
            try recordSession.setActive(true)
            try recordSession.overrideOutputAudioPort(.speaker)   //讓聲音從喇叭出來
            recordSession.requestRecordPermission { userYesOrNo in   //記錄使用者是否有授權
                if userYesOrNo {
                    self.recorderHasMic = true
                }else{
                    self.recorderHasMic = false
                    DispatchQueue.main.async { //只要有碰到UI的東西都放進main做安全
                        self.present(RecorderHelper.share.micNoPermission(), animated: true, completion: nil)
                    }
                }
            }
        } catch  {
            print("麥克風未授權\(error)")
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadFromCoreData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.playTimeSlider.isEnabled = false
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        self.editButtonItem.title = "編輯"
    }
    
    
    //MARK: Data Source
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.data.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let recordData = self.data[indexPath.row]
        cell.textLabel?.text = recordData.title
        cell.detailTextLabel?.text = NSString(format: "%02d:%02d:%02d", (Int(recordData.recordTime)/60)/60,(Int(recordData.recordTime)/60)%60,Int(recordData.recordTime)%60) as String
        return cell
    }
    //MARK: edit Delete
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if self.tableView.isEditing {
            tableView.isEditing = false
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
        self.tableView.setEditing(editing, animated: true)
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let alert = UIAlertController(title: "確定要刪除嗎？", message: "刪除後將無法復原", preferredStyle: .actionSheet)
        let ok = UIAlertAction(title: "刪除", style: .destructive) {[weak self] _ in
            guard let self = self else { return}
            let deleteData = self.data.remove(at: indexPath.row)
            self.moc.performAndWait {
                self.moc.delete(deleteData)
            }
            self.timeLabel.text = NSString(format: "%02d:%02d:%02d", 0,0,0) as String
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.editNameButton.isEnabled = false
            self.playButton.isEnabled = false
            self.stopButton.isEnabled = false
            self.shareButton.isEnabled = false
            self.saveToCoreData()
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
        if self.recorder == nil, self.player == nil {
            self.indexPath = indexPath
            let recordData = self.data[indexPath.row]
            self.settingSegment.selectedSegmentIndex = recordData.witchSetting
            selectedRowAboutButton()
            self.playTimeSlider.maximumValue = Float(recordData.recordTime)
            self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (Int(recordData.recordTime)/60)/60,(Int(recordData.recordTime)/60)%60,Int(recordData.recordTime)%60) as String
            print("\(indexPath)")
        }
    }
    
    //MARK: 錄音按鈕
    @IBAction func recorder(_ sender: UIButton) {
        if self.recorderHasMic{   //檢查有無授權
            if self.recorder == nil{  //沒設置過麥克風先設置
                let recordData = RecordData(context: moc)   //創造一個資料
                recordData.witchSetting = settingSegment.selectedSegmentIndex  //記錄錄音時的音質
                self.data.insert(recordData, at: 0)   //加進陣列裡面
                let indexPath = IndexPath(row: 0, section: 0)   //放到陣列最上方
                self.tableView.insertRows(at: [indexPath], with: .automatic)   //畫面做加入的更新
                self.saveToCoreData()
                do {     //設置麥克風
                    recorder = try RecorderHelper.share.setRecorder(fileName: recordData.recordID, setting: recordSetting)
                } catch  {
                    print("麥克風設置失敗\(error)")
                }
            }
            if let recorder = self.recorder {  //判斷是否正在錄音
                if recorder.isRecording{
                    recorder.pause()    //正在錄音按下按鈕就暫停
                    print("錄音暫停")
                    self.timer?.invalidate()
                    self.timer = nil
                    self.recordButton.setBackgroundImage(UIImage(systemName: "record.circle"), for: .normal)  //暫停時，按鈕改成在錄音鍵
                }else{
                    recorder.record()   //沒有錄音就錄音
                    print("錄音開始")
                    self.recordButton.setBackgroundImage(UIImage(systemName: "pause.circle"), for: .normal)   //錄音時，按鈕改成暫停鍵
                    if self.timer == nil {
                        self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updatedTimeLabel), userInfo: nil, repeats: true)
                    }
                    isRecordingAboutButton()
                }
            }
        }else{
            print("麥克風未授權")
            DispatchQueue.main.async {
                self.present(RecorderHelper.share.micNoPermission(), animated: true, completion: nil)
            }
        }
    }
    //MARK: 錄音時間
    @objc func updatedTimeLabel() {
        if let recorder = self.recorder {
            let recordTime = recorder.currentTime
            self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (Int(recordTime)/60)/60,(Int(recordTime)/60)%60,Int(recordTime)%60) as String
            
            let recordData = self.data[0]
            recordData.recordTime = Float(recordTime)
        }
    }
    //MARK: 停止按鈕
    @IBAction func stop(_ sender: UIButton) {
        if let recorder = self.recorder {
            recorder.stop()
            print("錄音停止")
            let indexPath = IndexPath(row: 0, section: 0)
            self.tableView.reloadRows(at:[indexPath] , with: .automatic)
            self.timer?.invalidate()
            self.timer = nil
            print("\(recorder.url)")
            self.recordButton.setBackgroundImage(UIImage(systemName: "circle.inset.filled"), for: .normal)
            self.recorder = nil
        }
        if let player = self.player {
            player.stop()
            self.playingTime = 0
            self.timer?.invalidate()
            self.timer = nil
            self.playButton.setBackgroundImage(UIImage(systemName: "play.circle"), for: .normal)
            self.player = nil
            if let indexPath = self.indexPath{
                let recordData = self.data[indexPath.row]
                self.timeLabel.text = NSString(format: "%02d:%02d:%02d", (Int(recordData.recordTime)/60)/60,(Int(recordData.recordTime)/60)%60,Int(recordData.recordTime)%60) as String
                self.playTimeSlider.value = 0
            }
        }
        allStopAboutButton()
        self.saveToCoreData()
    }
    //MARK: 播放按鈕
    @IBAction func play(_ sender: UIButton) {
        if self.player == nil {    //先設置麥克風
            do {
                if let indexPath = self.indexPath {
                    let recordData = self.data[indexPath.row]    //取出位置中的檔案
                    let recordURL = self.docURL.appendingPathComponent("\(recordData.recordID).wav")
                    self.player = try AVAudioPlayer(contentsOf: recordURL)
                }
            } catch  {
                print("麥克風設置失敗\(error)")
            }
        }
        if let player = self.player {
            if player.isPlaying{   //判斷是否正在播放
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
            }
            else  {  //播放結束
                self.playButton.setBackgroundImage(UIImage(systemName: "play.circle"), for: .normal)  //播放鍵變回一般的
                allStopAboutButton()
                self.playingTime = 0
                self.timer?.invalidate()     //計時器停止
                self.timer = nil
                self.player = nil
            }
        }
    }
    //MARK: 編輯名字
    @IBAction func editName(_ sender: Any) {
        if let indexPath = self.indexPath {
            let recordData = self.data[indexPath.row]    //取出位置中的檔案
            //使用alert來改名
            let alert = UIAlertController(title: "請輸入標題", message: nil, preferredStyle: .alert)
            let ok = UIAlertAction(title: "確定", style: .default) { _ in
                if let text = alert.textFields![0].text{
                    recordData.title = text}
                self.tableView.reloadRows(at: [indexPath], with: .automatic)  //改完名後，更新畫面
                self.playButton.isEnabled = false   //編輯結束，必須重選，按鈕才能按
                self.editNameButton.isEnabled = false
                self.playTimeSlider.isEnabled = false
            }
            let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            alert.addTextField(configurationHandler: { textField in
                textField.text = recordData.title})
            alert.addAction(ok)
            alert.addAction(cancel)
            present(alert, animated: true, completion: nil)
            self.saveToCoreData()
        }
    }
    //MARK: 換音質
    @IBAction func changeSetting(_ sender: UISegmentedControl) {
        switch settingSegment.selectedSegmentIndex {
        case 1 :
            //中音質
            recordSetting = RecorderHelper.share.recorderSetting(formatIDKey: kAudioFormatLinearPCM, sampleRateKey: 30000, encoderAudioQualityKey: AVAudioQuality.high.rawValue, numberOfChannelsKey: 1, linearPCMBitDepthKey: 24, encoderBitRateKey: 128000)
        case 2 :
            //高音質
            recordSetting  = RecorderHelper.share.recorderSetting(formatIDKey: kAudioFormatLinearPCM, sampleRateKey: 44100, encoderAudioQualityKey: AVAudioQuality.max.rawValue, numberOfChannelsKey: 1, linearPCMBitDepthKey: 32, encoderBitRateKey: 128000)
        default:
            //低音質
            recordSetting  = RecorderHelper.share.recorderSetting(formatIDKey: kAudioFormatLinearPCM, sampleRateKey: 16000, encoderAudioQualityKey: AVAudioQuality.medium.rawValue, numberOfChannelsKey: 1, linearPCMBitDepthKey: 16, encoderBitRateKey: 128000)
        }
    }
    //MARK: Core Data
    func saveToCoreData(){
        CoreDataHelper.shared.saveContext()
    }
    func loadFromCoreData(){
        let request = NSFetchRequest<RecordData>(entityName: "RecordData")
        moc.performAndWait {
            do {
                let result = try moc.fetch(request)
                self.data = result
            } catch  {
                print("讀檔失敗\(error)")
                self.data = []
            }
        }
    }
    //MARK: 離開畫面的時候
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let recorder = self.recorder {
            if recorder.isRecording {
                let indexPath = IndexPath(row: 0, section: 0)
                let recordData = self.data[indexPath.row]
                recordData.recordTime = Float(recorder.currentTime) //將時間存進timeText讓cell顯示
                recorder.stop()
                self.recorder = nil
            }
        }
        self.timer?.invalidate()
        self.timer = nil
        self.saveToCoreData()
    }
    
    //MARK: 傳送檔案
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBAction func share(_ sender: UIBarButtonItem) {
        if let indexPath = self.indexPath {
             let recordData = self.data[indexPath.row]     //取出位置中的檔案
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
    
}

