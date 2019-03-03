
Pod::Spec.new do |s|


  s.name         = 'JPVideoPlayer'
  s.version      = '3.2.0-beta'
  s.summary      = 'Automatic play video in UITableView like Weibo home page in main thread and never block main thread.'

  s.description  = 'This library provides an video player with cache support in UITableView.'\
                   'Cache video data at playing'\
                   'Handle play or stop video in mian-thread'\
                   'Excellent performance!'\
                   'Always play the video of the UITableViewCell in screen center when scrolling'\
                   'A guarantee that the same URL won\'t be downloaded several times'\
                   'A guarantee that main thread will never be blocked'

  s.homepage     = 'https://github.com/Chris-Pan/JPVideoPlayer'
  s.license      = 'MIT'
  s.author             = { 'NewPan' => '13246884282@163.com' }
  # s.platform     = :ios, '8.0'

  #  When using multiple platforms
  s.ios.deployment_target = '8.0'
  # s.osx.deployment_target = "10.7"
  # s.watchos.deployment_target = "2.0"
  # s.tvos.deployment_target = "9.0"


  s.source       = { :git => 'https://github.com/newyjp/JPVideoPlayer', :tag => s.version }
  s.source_files = 'JPVideoPlayer/**/*.{h,m}'
  s.resource     = 'JPVideoPlayer/JPVideoPlayer.bundle'
  s.frameworks   = 'Foundation', 'UIKit', 'AVFoundation', 'MobileCoreServices'
  s.requires_arc = true

end
