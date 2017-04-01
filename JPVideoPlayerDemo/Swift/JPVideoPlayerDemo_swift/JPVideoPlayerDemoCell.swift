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

public enum kJPPlayUnreachCellStyle : Int {
    
    case none // normal 播放滑动可及cell.
    
    case up // top 顶部不可及.
    
    case down // bottom 底部不可及.
}

class JPVideoPlayerDemoCell: UITableViewCell {
    
    public var videoPath = String()
    
    public var indexPath: IndexPath {
        get {
            return self.indexPath
        }
        set {
            let placeholderName = newValue.row % 2 == 0 ? "placeholder1" : "placeholder2"
            videoImv.image = UIImage(named: placeholderName)
        }
    }
    
    public var cellStyle : kJPPlayUnreachCellStyle? // cell类型
    
    @IBOutlet weak var videoImv: UIImageView!
}
