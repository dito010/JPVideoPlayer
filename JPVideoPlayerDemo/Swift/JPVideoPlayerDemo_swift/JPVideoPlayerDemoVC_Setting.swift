//
//  JPVideoPlayerDemoVC_Setting.swift
//  JPVideoPlayerDemo_swift
//
//  Created by 尹久盼 on 2017/5/2.
//  Copyright © 2017年 NewPan. All rights reserved.
//

import UIKit
import JPVideoPlayer

class JPVideoPlayerDemoVC_Setting: UIViewController {
    
    @IBOutlet weak var cacheLabel: UILabel!
    
    @IBOutlet weak var clearBtn: UIButton!
    
    @IBOutlet weak var githubBtn: UIButton!
    
    @IBOutlet weak var jianshuBtn: UIButton!
    
    @IBOutlet weak var wechatBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
    }
    
    @IBAction func clearBtnClick() {
        // Clear all cache.
        JPVideoPlayerCache.shared().clearDisk { [weak self] in
            print("clear disk finished, 清空磁盘完成")
            
            self?.calculateCacheMes()
        }
    }
    
    @IBAction func jianshuBtnClick() {
        gotoWebForGivenWebSite(website: "http://www.jianshu.com/u/e2f2d779c022")
    }
    
    @IBAction func githubBtnClick() {
        gotoWebForGivenWebSite(website: "https://github.com/Chris-Pan")
    }
    
    @IBAction func wechatBtnClick() {
        goWechat()
    }
}

extension JPVideoPlayerDemoVC_Setting {
    func gotoWebForGivenWebSite(website : String?) {
        if let web = website {
            UIApplication.shared.openURL(URL(string: web)!)
        }
    }
    
    func goWechat() {
        let vc = UIViewController()
        vc.hidesBottomBarWhenPushed = true
        vc.view.backgroundColor = UIColor.white
        vc.title = "NewPan 的微信二维码"
        
        let imv = UIImageView()
        imv.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
        imv.center = vc.view.center
        vc.view.addSubview(imv)
        let colors = [UIColor.init(red: 98.0/255.0, green: 152.0/255.0, blue: 209.0/255.0, alpha: 1), UIColor.init(red: 190.0/255.0, green: 53.0/255.0, blue: 77.0/255.0, alpha: 1)]
        let img =  JPQRCodeTool.generateCode(for: "http://weixin.qq.com/r/FeMxKeHeT7wwraVK97YH", with: kQRCodeCorrectionLevel.qrCodeCorrectionLevelHight, sizeType: kQRCodeSizeType.qrCodeSizeTypeNormal, customSizeDelta: 0, drawType: kQRCodeDrawType.qrCodeDrawTypeCircle, gradientType: kQRCodeGradientType.qrCodeGradientTypeDiagonal, gradientColors: colors)
        imv.image = img
        
        navigationController?.pushViewController(vc, animated: true)
    }
}

extension JPVideoPlayerDemoVC_Setting {
    func setup() {
        navigationController?.navigationBar.isHidden = true
        
        clearBtn.layer.cornerRadius = 5.0
        githubBtn.layer.cornerRadius = 5.0
        jianshuBtn.layer.cornerRadius = 5.0
        wechatBtn.layer.cornerRadius = 5.0
        
        calculateCacheMes()
    }
    
    func calculateCacheMes() {
        // Count all cache size.
        JPVideoPlayerCache.shared().calculateSize { [weak self] (fileCount, totalSize) in
            var cacheMes = String(format: "总缓存大小: %0.2fMB, 总缓存文件数: \(fileCount) 个", CGFloat(totalSize)/1024.0/1024.0)
            self?.cacheLabel.text = cacheMes
            
            cacheMes = cacheMes.appending(", 你可以使用框架提供的方法, 清除所有缓存或指定的缓存, 具体请查看 `JPVideoPlayerCache`")
            print(cacheMes)
        }
    }
}
