
<p align="center" >
<img src="Images/JPVideoPlayer.png" title="JPVideoPlayer logo" float=left>
</p>
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/Chris-Pan/JPVideoPlayer) [![pod](https://img.shields.io/badge/pod-1.4.1-brightgreen.svg)](https://github.com/Chris-Pan/JPVideoPlayer) [![pod](https://img.shields.io/badge/platform-iOS-ff69b4.svg)](https://github.com/Chris-Pan/JPVideoPlayer) [![pod](https://img.shields.io/badge/about%20me-NewPan-blue.svg)](http://www.jianshu.com/users/e2f2d779c022/latest_articles)

This library provides an video player with cache support in `UITableView`.

<p align="center" >
<img src="Images/JPVideoPlayer.gif" title="JPVideoPlayer Demo" float=left>
</p>

## Watch out
You may download my demo to know how to play video in UITableViewController, this framework just provides a player cache video data at playing.

## Features

- [x] Cache video data at playing
- [x] Handle play or stop video in main thread
- [x] Excellent performance!
- [x] Always play the video of the `UITableViewCell` in screen center when scrolling   
- [x] A guarantee that the same URL won't be downloaded several times
- [x] A guarantee that main thread will never be blocked


## Requirements

- iOS 8.0 or later
- Xcode 7.3 or later


## Getting Started

- Read the [[iOS]仿微博视频边下边播之封装播放器](http://www.jianshu.com/p/0d4588a7540f)
- Read the [[iOS]仿微博视频边下边播之滑动TableView自动播放](http://www.jianshu.com/p/3946317760a6)
- Try the example by downloading the project from Github


## Communication

- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.


## Installation

## How To Use

```objective-c
Objective-C:

#import <JPVideoPlayer/JPVideoPlayer.h>
...
JPVideoPlayer *player = [JPVideoPlayer sharedInstance];
[player playWithUrl:[NSURL URLWithString:videoCell.videoPath] showView:videoCell.containerView];
```

Installation
------------

There are two ways to use JPVideoPlayer in your project:
- using CocoaPods
- by cloning the project into your repository

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries in your projects. See the [Get Started](http://cocoapods.org/#get_started) section for more details.

#### Podfile
```
platform :ios, '8.0'
target “YourProjectName” do
pod 'JPVideoPlayer', '~> 1.4.1'
end
```

## Licenses

All source code is licensed under the [MIT License](https://github.com/Chris-Pan/JPVideoPlayer/blob/master/LICENSE).



如果你在天朝
------------
## 注意:
如果你需要在UITableViewController中滑动播放视频, 请下载我的完整demo, 这个框架只提供一个边下边缓存视频数据的播放器.

## 特性

- [x] 视频播放边下边播
- [x] 主线程处理切换视频
- [x] 不阻塞线程，不卡顿，滑动如丝顺滑
- [x] 当滚屏时采取总是播放处在屏幕中心的那个cell的视频的策略
- [x] 保证同一个URL的视频不会重复下载
- [x] 保证不会阻塞线程


## 组件要求

- iOS 8.0 +
- Xcode 7.3 +


## 如何使用

- 阅读我的简书文章 [[iOS]仿微博视频边下边播之封装播放器](http://www.jianshu.com/p/0d4588a7540f)
- 阅读我的简书文章 [[iOS]仿微博视频边下边播之滑动TableView自动播放](http://www.jianshu.com/p/3946317760a6)
- 下载我Github上的demo


## 联系

- 如果你发现了bug, 请帮我提交issue
- 如果你有好的建议, 请帮我提交issue
- 如果你想贡献代码, 请提交请求


## 如何使用

```objective-c
Objective-C:

#import <JPVideoPlayer/JPVideoPlayer.h>
...
JPVideoPlayer *player = [JPVideoPlayer sharedInstance];
[player playWithUrl:[NSURL URLWithString:videoCell.videoPath] showView:videoCell.containerView];
```

## 如何安装

两种选择把框架集成到你的项目:
- 使用 CocoaPods
- 下载我的demo, 把'JPVideoPlayer'文件夹拽到你的项目中

### 使用 CocoaPods 安装

#### Podfile
```
platform :ios, '8.0'
target “你的项目名称” do
pod 'JPVideoPlayer', '~> 1.4.1'
end
```

## 证书

[MIT License](https://github.com/Chris-Pan/JPVideoPlayer/blob/master/LICENSE)

## 如果喜欢我的文章，请帮忙点个👍。
