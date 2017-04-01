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

/*
 * The scroll derection of tableview.
 */
public enum kJPVideoPlayerDemoScrollDerection: Int {
    
    case none
    
    case up // scroll up.
    
    case down // scroll down.
}

let JPVideoPlayerDemoNavAndStatusTotalHei : CGFloat = 64.0
let screenSize = UIScreen.main.bounds.size
let JPVideoPlayerDemoReuseID = "JPVideoPlayerDemoReuseID"
let  JPVideoPlayerDemoRowHei : CGFloat = CGFloat(screenSize.width)*9.0/16.0

class JPVideoPlayerDemoVC_home: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if playingCell==nil {
            
            // Find the first cell need to play video in visiable cells.
            // 在可见cell中找第一个有视频的进行播放.
            playVideoInVisiableCells()
        }
        else{
            let url = NSURL(string: (playingCell?.videoPath)!)
            playingCell?.videoImv.jp_playVideoMutedDisplayStatusView(with: url as URL?)
        }
        tableViewRange.isHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        tableViewRange.isHidden = true
        
        if (playingCell != nil) {
            playingCell?.videoImv.stopPlay()
        }
    }
    
    // MARK: - Properties
    
    lazy var tableViewRange : UIView = self.generateTableViewRange()
    
    let generateTableViewRange = { () -> UIView in
        let tableViewRange = UIView(frame: CGRect(x: 0, y: JPVideoPlayerDemoNavAndStatusTotalHei, width: screenSize.width, height: screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei))
        tableViewRange.isUserInteractionEnabled = false
        tableViewRange.backgroundColor = UIColor.clear
        tableViewRange.isHidden = true
        return tableViewRange
    }
    
    // video paths
    lazy var videoPathStrings: Array = {
        return [
            "http://lavaweb-10015286.video.myqcloud.com/%E5%B0%BD%E6%83%85LAVA.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/lava-guitar-creation-2.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/hong-song-mei-gui-mu-2.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/ideal-pick-2.mp4",
            
            // This path is a https.
            // "https://bb-bang.com:9002/Test/Vedio/20170110/f49601b6bfe547e0a7d069d9319388f4.mp4",
            // "http://123.103.15.1JPVideoPlayerDemoNavAndStatusTotalHei:8880/myVirtualImages/14266942.mp4",
            
            // This video saved in amazon, maybe load sowly.
            // "http://vshow.s3.amazonaws.com/file147801253818487d5f00e2ae6e0194ab085fe4a43066c.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_01.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_02.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_03.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_04.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_05.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_06.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_07.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_08.mp4",
            
            // To simulate the cell have no video to play.
            // "",
            "http://120.25.226.186:32812/resources/videos/minion_10.mp4",
            "http://120.25.226.186:32812/resources/videos/minion_11.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/%E5%B0%BD%E6%83%85LAVA.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/lava-guitar-creation-2.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/hong-song-mei-gui-mu-2.mp4",
            "http://lavaweb-10015286.video.myqcloud.com/ideal-pick-2.mp4"]
    }()
    
    // The cell of playing video.
    var playingCell : JPVideoPlayerDemoCell?
    
    // The scroll derection of tableview now.
    var currentDerection = kJPVideoPlayerDemoScrollDerection.none
    
    /**
     * Because we start to play video on cell only when the tableview was stoped scrolling and the cell stoped on screen center, so always some cells cannot stop in screen center maybe, the cells always is those on top or bottom in tableview.
     * So we need handle this especially. But first we need do is that to check the situation of this type cell appear.
     * Here is the result of my measure on iPhone 6s(CH).
     * The number of visiable cells in screen:              4  3  2
     * The number of cells cannot stop in screen center:    1  1  0
     * Tip : you need to know that the mean of result, For example, when we got 4 cells in screen, this time mean that we find 1 cell of cannot stop in screen center on top, and we got the cell of cannot stop in screen center on bottom at the same time.
     * Watch out : the cell of cannot stop in screen center only appear when the number of visiable cell is greater than 3.
     *
     * 由于我们是在tableView静止的时候播放停在屏幕中心的cell, 所以可能出现总有一些cell无法满足我们的播放条件.
     * 所以我们必须特别处理这种情况, 我们首先要做的就是检查什么样的情况下才会出现这种类型的cell.
     * 下面是我的测量结果(iPhone 6s, iPhone 6 plus).
     * 每屏可见cell个数           4  3  2
     * 滑动不可及的cell个数        1  1  0
     * 注意 : 你需要仔细思考一下我的测量结果, 举个例子, 如果屏幕上有4个cell, 那么这个时候, 我们能够在顶部发现一个滑动不可及cell, 同时, 我们在底部也会发现一个这样的cell.
     * 注意 : 只有每屏可见cell数在3以上时,才会出现滑动不可及cell.
     */
    lazy var dictOfVisiableAndNotPlayCells: Dictionary<String, Int> = {
        return ["4" : 1, "3" : 1, "2" : 0]
    }()
    
    // The number of cells cannot stop in screen center.
    var maxNumCannotPlayVideoCells: Int {
        let radius = screenSize.height / JPVideoPlayerDemoRowHei
        let maxNumOfVisiableCells = Int(ceilf(Float(radius)))
        if maxNumOfVisiableCells >= 3 {
            return dictOfVisiableAndNotPlayCells["\(maxNumOfVisiableCells)"]!
        }
        return 0
    }    
    
    /**
     * For calculate the scroll derection of tableview, we need record the offset-Y of tableview when begain drag.
     * 刚开始拖拽时scrollView的偏移量Y值, 用来判断滚动方向.
     */
    var offsetY_last : CGFloat = 0.0
}

extension JPVideoPlayerDemoVC_home {
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        return videoPathStrings.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell : JPVideoPlayerDemoCell = tableView.dequeueReusableCell(withIdentifier: JPVideoPlayerDemoReuseID, for: indexPath) as! JPVideoPlayerDemoCell
        cell.selectionStyle = UITableViewCellSelectionStyle.none
        cell.indexPath = indexPath
        cell.videoPath = videoPathStrings[indexPath.row]
        
        if maxNumCannotPlayVideoCells>0 {
            if indexPath.row<=maxNumCannotPlayVideoCells-1 { // 上不可及
                cell.cellStyle = kJPPlayUnreachCellStyle.up
            }
            else if indexPath.row>=videoPathStrings.count-maxNumCannotPlayVideoCells { // 下不可及
                cell.cellStyle = kJPPlayUnreachCellStyle.down
            }
            else{
                cell.cellStyle = kJPPlayUnreachCellStyle.none
            }
        }
        else{
            cell.cellStyle = kJPPlayUnreachCellStyle.none
        }
        return cell
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return JPVideoPlayerDemoRowHei
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let single = JPVideoPlayerDemoVC_present()
        present(single, animated: true, completion: nil)
        let cell = tableView.cellForRow(at: indexPath) as! JPVideoPlayerDemoCell
        single.videoPath = cell.videoPath
    }
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        offsetY_last = scrollView.contentOffset.y
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        handleScrollDerectionWithOffset(offsetY: scrollView.contentOffset.y)
        handleQuickScroll()
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate==false {
            handleScrollStop()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        handleScrollStop()
    }
}

extension JPVideoPlayerDemoVC_home {
    
    func setup() {
        setupNavBar()
        setupTableView()
        displayTableViewRange()
        viewDidLoadEvents()
    }
    
    func setupNavBar() {
        let navBarImv = UIImageView(frame: CGRect(x: 0, y: -20, width: screenSize.width, height: JPVideoPlayerDemoNavAndStatusTotalHei))
        navBarImv.image = UIImage(named: "navbar")
        navigationController?.navigationBar.addSubview(navBarImv)
    }
    
    func setupTableView() {
        tableView.dataSource = self;
        tableView.delegate = self;
        tableView.register(UINib.init(nibName: "JPVideoPlayerDemoCell", bundle: nil), forCellReuseIdentifier: JPVideoPlayerDemoReuseID)
        
        // location file in disk.
        guard let locVideoPath = Bundle.main.path(forResource: "hello", ofType: "mp4") else {
            return
        }
        let url = URL(fileURLWithPath: locVideoPath)
        videoPathStrings.insert(url.absoluteString, at: 0)
        tableView.reloadData()
    }
    
    func displayTableViewRange() {
        UIApplication.shared.keyWindow!.insertSubview(tableViewRange, aboveSubview: tableView)
        addDashLineToTableViewRange()
    }
    
    func addDashLineToTableViewRange() {
        let linePath1 = UIBezierPath()
        linePath1.move(to: CGPoint(x: 1, y: 1))
        linePath1.addLine(to: CGPoint(x: screenSize.width-1, y: 1))
        linePath1.addLine(to: CGPoint(x: screenSize.width-1, y: screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1))
        linePath1.addLine(to: CGPoint(x: 1, y: screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1))
        linePath1.addLine(to: CGPoint(x: 1, y: 1))
        
        let layer1 = CAShapeLayer()
        let drawColor1 = UIColor(colorLiteralRed: 1, green: 0, blue: 0, alpha: 1)
        layer1.path = linePath1.cgPath
        layer1.strokeColor = drawColor1.cgColor
        layer1.fillColor = UIColor.clear.cgColor
        layer1.lineWidth = 1
        layer1.lineDashPattern = [6, 3]
        layer1.lineCap = "round"
        tableViewRange.layer.addSublayer(layer1)
        
        let linePath2 = UIBezierPath()
        linePath2.move(to: CGPoint(x: 1, y: 0.5*(screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1)))
        linePath2.addLine(to: CGPoint(x: screenSize.width-1, y: 0.5*(screenSize.height-JPVideoPlayerDemoNavAndStatusTotalHei-1)))
        
        let layer2 = CAShapeLayer()
        let drawColor2 = UIColor(colorLiteralRed: 0, green: 0.98, blue: 0, alpha: 1)
        layer2.path = linePath2.cgPath
        layer2.strokeColor = drawColor2.cgColor
        layer2.fillColor = UIColor.clear.cgColor
        layer2.lineWidth = 1
        layer2.lineDashPattern = [6, 3]
        layer2.lineCap = "round"
        tableViewRange.layer.addSublayer(layer2)
    }
    
    func viewDidLoadEvents() {
        // Count all cache size.
        JPVideoPlayerCache.shared().calculateSize { (fileCount, totalSize) in
            print("Total cache size, 总缓存大小: \(CGFloat(totalSize)/1024.0/1024.0)/MB, 总缓存文件数: \(fileCount), 你可以使用框架提供的方法, 清除所有缓存或指定的缓存, 具体请查看 `JPVideoPlayerCache`")
        }
        
        // Clear all cache.
        // JPVideoPlayerCache.shared().clearDisk {
        //    print("ClearDiskFinished, 清空磁盘完成")
        // }
    }
}

extension JPVideoPlayerDemoVC_home {
    
    // Find first cell need play video in visiable cells.
    func playVideoInVisiableCells() {
        let visiableCells = tableView.visibleCells
        
        var targetCell : JPVideoPlayerDemoCell?
        for c in visiableCells {
            let cell = c as! JPVideoPlayerDemoCell
            if cell.videoPath.characters.count>0 {
                targetCell = cell
                break
            }
        }
        
        // If found, play.
        guard let videoCell = targetCell else {
            return
        }
        playingCell = videoCell
        
        // display status view.
        videoCell.videoImv.jp_playVideoMutedDisplayStatusView(with: URL(string: videoCell.videoPath))
        
        // hide status view.
        videoCell.videoImv.jp_playVideoMuted(with: URL(string: videoCell.videoPath))
    }
    
    func handleScrollStop() {
        
        guard let bestCell = findTheBestToPlayVideoCell() else {
            return
        }
        
        // If the found cell is the cell playing video, this situation cannot play video again.
        // 注意, 如果正在播放的 cell 和 finnalCell 是同一个 cell, 不应该在播放.
        if playingCell?.hash != bestCell.hash {
            playingCell?.videoImv.stopPlay()
            
            let url = NSURL(string: bestCell.videoPath)
            
            // display status view.
            bestCell.videoImv.jp_playVideoMutedDisplayStatusView(with: url as URL?)
            
            // hide status view.
            // bestCell.videoImv.jp_playVideoMuted(with: url as URL?)
            
            playingCell = bestCell
        }
    }
    
    func handleQuickScroll() {
        if playingCell?.hash==0 {
            return
        }
        
        // Stop play when the cell playing video is unvisiable.
        // 当前播放视频的cell移出视线，要移除播放器.
        if !playingCellIsVisiable() {
            stopPlay()
        }
    }
    
    func stopPlay() {
        playingCell?.videoImv.stopPlay()
        playingCell = nil
    }
    
    func handleScrollDerectionWithOffset(offsetY : CGFloat) {
        currentDerection = (offsetY-offsetY_last) > 0 ? kJPVideoPlayerDemoScrollDerection.up : kJPVideoPlayerDemoScrollDerection.down
        offsetY_last = offsetY
    }
}

extension JPVideoPlayerDemoVC_home{
    
    func findTheBestToPlayVideoCell() -> JPVideoPlayerDemoCell? {
        
        var windowRect = UIScreen.main.bounds
        windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
        windowRect.size.height -= JPVideoPlayerDemoNavAndStatusTotalHei;
        
        // To find next cell need play video.
        // 找到下一个要播放的cell(最在屏幕中心的).

        var finialCell : JPVideoPlayerDemoCell?
        let visiableCells : [JPVideoPlayerDemoCell] = tableView.visibleCells as! [JPVideoPlayerDemoCell];
        var gap : CGFloat = CGFloat(MAXFLOAT)
        for cell in visiableCells {
            
            if cell.videoPath.characters.count>0 { // If need to play video, 如果这个cell有视频
                
                // Find the cell cannot stop in screen center first.
                // 优先查找滑动不可及cell.
                if cell.cellStyle != kJPPlayUnreachCellStyle.none {
                    
                    // Must the all area of the cell is visiable.
                    // 并且不可及cell要全部露出.
                    if cell.cellStyle == kJPPlayUnreachCellStyle.up {
                        var cellLeftUpPoint = cell.frame.origin
                        // 不要在边界上.
                        cellLeftUpPoint.y += 1
                        let coorPoint = cell.superview?.convert(cellLeftUpPoint, to: nil)
                        let contain = windowRect.contains(coorPoint!)
                        if  contain {
                            finialCell = cell
                            break
                        }
                    }
                    else if(cell.cellStyle == kJPPlayUnreachCellStyle.down){
                        let cellLeftUpPoint = cell.frame.origin
                        let cellDownY = cellLeftUpPoint.y+cell.frame.size.height
                        var cellLeftDownPoint = CGPoint(x: 0, y: cellDownY)
                        // 不要在边界上.
                        cellLeftDownPoint.y -= 1
                        let coorPoint = cell.superview?.convert(cellLeftDownPoint, to: nil)
                        let contain = windowRect.contains(coorPoint!)
                        if contain {
                            finialCell = cell
                            break;
                        }
                    }
                }
                else{
                    let coorCenter = cell.superview?.convert(cell.center, to: nil)
                    let delta = fabs((coorCenter?.y)!-JPVideoPlayerDemoNavAndStatusTotalHei-windowRect.size.height*0.5)
                    if delta < gap {
                        gap = delta
                        finialCell = cell
                    }
                }
            }
        }
        return finialCell
    }

    func playingCellIsVisiable() -> Bool {
        guard let cell = playingCell else {
            return true
        }
        
        var windowRect = UIScreen.main.bounds
        windowRect.origin.y = JPVideoPlayerDemoNavAndStatusTotalHei;
        // because have UINavigationBar here.
        windowRect.size.height -= JPVideoPlayerDemoNavAndStatusTotalHei;
        
        if currentDerection==kJPVideoPlayerDemoScrollDerection.up { // 向上滚动
            let cellLeftUpPoint = cell.frame.origin
            let cellDownY = cellLeftUpPoint.y+cell.frame.size.height
            var cellLeftDownPoint = CGPoint(x: 0, y: cellDownY)
            // 不要在边界上.
            cellLeftDownPoint.y -= 1
            let coorPoint = playingCell?.superview?.convert(cellLeftDownPoint, to: nil)
            
            let contain = windowRect.contains(coorPoint!)
            return contain
        }
        else if(currentDerection==kJPVideoPlayerDemoScrollDerection.down){ // 向下滚动
            var cellLeftUpPoint = cell.frame.origin
            // 不要在边界上.
            cellLeftUpPoint.y += 1
            let coorPoint = cell.superview?.convert(cellLeftUpPoint, to: nil)
            
            let contain = windowRect.contains(coorPoint!)
            return contain
        }
        return true
    }
}
