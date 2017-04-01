/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/Chris-Pan
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

import UIKit
import JPVideoPlayer

// MARK: 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).

class JPVideoPlayerDemoVC_present: UIViewController {
    
    var videoPath = String()
    
    @IBOutlet weak var videoImv: UIImageView!
    
    @IBOutlet weak var muteSwitch: UISwitch!
    
    @IBOutlet weak var autoReplaySwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoImv.videoPlayerDelegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let url = NSURL(string: videoPath)
        videoImv.jp_playVideoDisplayStatusView(with: url as URL?)
        videoImv.perfersProgressViewColor(UIColor.red)
        muteSwitch.isOn = !videoImv.playerIsMute()
    }
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        videoImv.stopPlay()
    }
    
    @IBAction func muteSwitch(_ sender: UISwitch) {
        videoImv.setPlayerMute(!sender.isOn)
    }

    @IBAction func closeBtnClick() {
        dismiss(animated: true, completion: nil)
    }
}

extension JPVideoPlayerDemoVC_present : JPVideoPlayerDelegate{
    func shouldAutoReplayAfterPlayComplete(for videoURL: URL) -> Bool {
        return autoReplaySwitch.isOn
    }
}
