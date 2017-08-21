//
//  JPVideoPlayerDemoVC_push.swift
//  JPVideoPlayerDemo_swift
//
//  Created by 尹久盼 on 2017/7/29.
//  Copyright © 2017年 NewPan. All rights reserved.
//

import UIKit
import JPVideoPlayer

// MARK: 注意: 播放视频的工具类是单例, 单例生命周期为整个应用生命周期, 故而须在 `-viewWillDisappear:`(推荐)或其他方法里 调用 `stopPlay` 方法来停止视频播放, 否则当前控制器销毁了, 视频仍然在后台播放, 虽然看不到图像, 但是能听到声音(如果有).

class JPVideoPlayerDemoVC_push: UIViewController {
    
    var videoPath : String?
    
    var tapGestureRecognize = UITapGestureRecognizer()
    
    
    @IBOutlet weak var muteSwitch: UISwitch!
    
    @IBOutlet weak var playOrPauseSwitch: UISwitch!
    
    @IBOutlet weak var autoReplaySwitch: UISwitch!
    
    var videoContainer = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        videoContainer.jp_stopPlay()
    }
    
    @IBAction func muteSwitchValueChanged(_ sender: UISwitch) {
        videoContainer.jp_setPlayerMute(!sender.isOn)
    }
    
    @IBAction func playOrPauseSwitchValueChanged(_ sender: UISwitch) {
        sender.isOn ? videoContainer.jp_resume() : videoContainer.jp_pause()
    }
    
    
    @IBAction func closeBtnClick(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
}

extension JPVideoPlayerDemoVC_push : JPVideoPlayerDelegate {
    
    func shouldAutoReplayAfterPlayComplete(for videoURL: URL) -> Bool {
        return autoReplaySwitch.isOn;
    }
}

extension JPVideoPlayerDemoVC_push {
    func setup() {
        self.navigationController?.navigationBar.isHidden = true
        self.navigationController?.jp_useCustomPopAnimationForCurrentViewController = true
       
        setupVideoEvents()
        setupTouchEvents()
    }

    func setupVideoEvents() {
        videoContainer = UIView()
        let screenWidth = UIScreen.main.bounds.size.width
        videoContainer.frame = CGRect(x: 0, y: 100, width: screenWidth, height: screenWidth * 9.0 / 16.0)
        self.view.addSubview(videoContainer)
        videoContainer.jp_videoPlayerDelegate = self
        guard let path = videoPath else {
            return
        }
        videoContainer.jp_playVideo(with: URL(string: path))
    }
    
    func setupTouchEvents() {
        tapGestureRecognize = UITapGestureRecognizer(target: self, action: #selector(self.didTapVideoView(gestureRecognizer:)))
        videoContainer.addGestureRecognizer(tapGestureRecognize)
    }
    
    func didTapVideoView(gestureRecognizer : UITapGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.ended {
            if videoContainer.viewStatus == JPVideoPlayerVideoViewStatus.portrait {
                videoContainer.jp_gotoLandscape(animated: true, completion: nil)
            }
            else if (videoContainer.viewStatus == JPVideoPlayerVideoViewStatus.landscape){
                videoContainer.jp_gotoPortrait(animated: true, completion: nil)
            }
        }
    }
}
