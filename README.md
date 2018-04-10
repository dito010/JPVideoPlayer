# Readme

<p align="left" >
<img src="Images/JPVideoPlayer.png" title="JPVideoPlayer logo" float=left>
</p>

[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/newyjp/JPVideoPlayer)
[![pod](https://img.shields.io/badge/pod-3.0.0-green.svg)](https://github.com/newyjp/JPVideoPlayer) 
[![pod](https://img.shields.io/badge/about%20me-NewPan-red.svg)](http://www.jianshu.com/users/e2f2d779c022/latest_articles) 
[![pod](https://img.shields.io/badge/swift-support-fc2f24.svg?maxAge=2592000)](https://github.com/apple/swift)
[![pod](https://img.shields.io/badge/Carthage-support-green.svg)](https://github.com/Carthage/Carthage)

This library provides an video player with cache support in `UITableView`.

<p align="left" >
<img src="Images/demo.gif" title="demo" float=left>
</p>

## Features
- [x] Cache video data at playing.
- [x] Seek time support(new).
- [x] Breakpoint continuingly support(new).
- [x] Landscape auto-layout support(new).
- [x] Custom player controlView support(new).
- [x] Excellent performance!
- [x] A guarantee that the same URL won't be downloaded several times
- [x] A guarantee that main thread will never be blocked
- [x] Location video play support
- [x] Swift support
- [x] Carthage support

## Requirements
- iOS 8.0 or later
- Xcode 7.3 or later

## Getting Started
- Read [[iOS]仿微博视频边下边播之封装播放器](http://www.jianshu.com/p/0d4588a7540f)
- Read [[iOS]仿微博视频边下边播之滑动TableView自动播放](http://www.jianshu.com/p/3946317760a6)
- Read [[iOS]从使用 KVO 监听 readonly 属性说起](http://www.jianshu.com/p/abd238407e0d)
- Read [[iOS]如何重新架构 JPVideoPlayer ?](http://www.jianshu.com/p/66638bdfd537)
- Try the example by downloading the project from Github

## How To Use
#### Mute play video and display progressView in `UITableView`.
```objective-c

NSURL *url = [NSURL URLWithString:@"http://p11s9kqxf.bkt.clouddn.com/bianche.mp4"];
[aview jp_playVideoMuteWithURL:url
            bufferingIndicator:nil
                  progressView:nil
       configurationCompletion:nil];
```


#### Resume play from `UITableView` to 
```objective-c
Objective-C:

#import <UIView+WebVideoCache.h>

...
NSURL *url = [NSURL URLWithString:@"http://lavaweb-10015286.video.myqcloud.com/%E5%B0%BD%E6%83%85LAVA.mp4"];
[aview jp_playVideoHiddenStatusViewWithURL:url];
```

#### Play video muted, hidden status view.
```objective-c
Objective-C:

#import <UIView+WebVideoCache.h>

...
NSURL *url = [NSURL URLWithString:@"http://lavaweb-10015286.video.myqcloud.com/%E5%B0%BD%E6%83%85LAVA.mp4"];
[aview jp_playVideoMutedHiddenStatusViewWithURL:url];
```

#### Play video muted, display status view.
```objective-c
Objective-C:

#import <UIView+WebVideoCache.h>

...
NSURL *url = [NSURL URLWithString:@"http://lavaweb-10015286.video.myqcloud.com/%E5%B0%BD%E6%83%85LAVA.mp4"];
[aview jp_playVideoMutedDisplayStatusViewWithURL:url];
```

#### Custom progress view.
```Objective-C:

#import <UIView+WebVideoCache.h>

...
[aview jp_perfersDownloadProgressViewColor: [UIColor grayColor]];
[aview jp_perfersPlayingProgressViewColor: [UIColor blueColor]];
```

#### Player control.
```Objective-C:

#import <UIView+WebVideoCache.h>

...
[aview jp_stopPlay];
[aview jp_pause];
[aview jp_resume];
[aview jp_setPlayerMute:YES];
```

#### Landscape Or Portrait Control
```Objective-C:

#import <UIView+WebVideoCache.h>

...
[aview jp_landscapeAnimated:YES completion:nil];
[aview jp_portraitAnimated:YES completion:nil];
```


#### Cache manage.
```Objective-C:

#import <JPVideoPlayerCache.h>

...
[[JPVideoPlayerCache sharedCache] calculateSizeWithCompletionBlock:^(NSUInteger fileCount, NSUInteger totalSize) {
// do something.
}];

[[JPVideoPlayerCache sharedCache] clearDiskOnCompletion:^{
// do something
}];
```


Installation
------------

There are three ways to use JPVideoPlayer in your project:
- using CocoaPods
- using Carthage
- by cloning the project into your repository

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries in your projects. See the [Get Started](http://cocoapods.org/#get_started) section for more details.

#### Podfile
```
platform :ios, '8.0'
target "YourProjectName" do
pod 'JPVideoPlayer', '~> 2.4.0'
end
```

### Installation with Carthage
[Carthage](https://github.com/Carthage/Carthage) is a simple, decentralized dependency manager for Cocoa.

```
github "newyjp/JPVideoPlayer"

```


## Communication
- If you **found a bug**, open an issue please.
- If you **have a feature request**, open an issue please.
- If you **want to contribute**, submit a pull request please.

## Licenses
All source code is licensed under the [MIT License](https://github.com/Chris-Pan/JPVideoPlayer/blob/master/LICENSE).

## Architecture
<p align="left" >
<img src="Images/JPVideoPlayerSequenceDiagram.png" title="JPVideoPlayerSequenceDiagram" float=left>
</p>
