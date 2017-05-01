

<p align="center" >
<img src="Images/logo.png" title="JPNavigationController logo" float=left>
</p>
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/Chris-Pan/JPNavigationController) [![pod](https://img.shields.io/badge/pod-1.2.5-brightgreen.svg)](https://github.com/Chris-Pan/JPNavigationController) [![pod](https://img.shields.io/badge/platform-iOS-ff69b4.svg)](https://github.com/Chris-Pan/JPNavigationController) [![pod](https://img.shields.io/badge/about%20me-NewPan-blue.svg)](http://www.jianshu.com/users/e2f2d779c022/latest_articles)

This library provides an fullScreen pop and push gesture for UINavigationController with customize UINavigationBar for each single support. 

<p align="center" >
<img src="Images/JPNavigationController.gif" title="JPNavigationController Demo" float=left>
</p>


## Features

- [x] FullScreen pop gesture support
- [x] FullScreen push gesture support
- [x] Customize UINavigationBar for each single viewController support
- [x] Add link view hovering in screen bottom support
- [x] Customize pop and push gesture distance on the left side of the screen support
- [x] Close pop gesture for single viewController support
- [x] Close pop gesture for all viewController support


## Requirements

- iOS 8.0 or later
- Xcode 8.0 or later


## Getting Started

- Read the [[iOS]UINavigationController全屏pop之为每个控制器自定义UINavigationBar](http://www.jianshu.com/p/88bc827f0692)
- Read the [[iOS]UINavigationController全屏pop之为每个控制器添加底部联动视图](http://www.jianshu.com/p/3ed21414551a)
- Read the [[iOS]UINavigationController全屏pop之为控制器添加左滑push](http://www.jianshu.com/p/ff68b5e646fc)
- Try the example by downloading the project from Github


## Communication

- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.


## Installation

## How To Use

#### Initialize

```objective-c
Objective-C:

#import <JPNavigationControllerKit.h>

JPNavigationController *nav = [[JPNavigationController alloc]initWithRootViewController:YourVc];
```

#### PushViewController

```objective-c
Objective-C:

[self.navigationController pushViewController:YourVc animated:YES];
```

#### PopToViewController

```objective-c
Objective-C:

[self.navigationController popViewControllerAnimated:YES];

[self.navigationController popToRootViewControllerAnimated:YES];


// Pop to a given view controller.

// Plan A: find the target view controller by youself, then pop it.
JPSecondVC *second = nil;
NSArray *viewControllers = self.navigationController.jp_rootNavigationController.jp_viewControllers;
for (UIViewController *c in viewControllers) {
    if ([c isKindOfClass:[JPSecondVC class]]) {
        second = (JPSecondVC *)c;
        break;
    }
}

if (second) {
    [self.navigationController popToViewController:second animated:YES];
}


// Plan B: use jp_popToViewControllerClassIs: animated:.
[self.navigationController jp_popToViewControllerClassIs:[JPSecondVC class] animated:YES];
```


#### Customize UINavigationBar

```objective-c
Objective-C:

// Hide navigation bar.
self.navigationController.navigationBarHidden = YES;

// Customize UINavigationBar color
[self.navigationController.navigationBar setBackgroundImage:aImage forBarMetrics:UIBarMetricsDefault];

```

#### Add push gesture connect viewController

```objective-c
Objective-C:

// Become the delegate of JPNavigationControllerDelegate protocol and, implemented protocol method, then you own left-slip to push function.
self.navigationController.jp_delegate = self;

// Implementation protocol method
-(void)jp_navigationControllerDidPushLeft{
    [self.navigationController pushViewController:YourVc animated:YES];
}
```

#### Add link view hovering in screen bottom

```objective-c
Objective-C:

// Return the link view in the be pushed viewController.
-(void)viewDidLoad{
    [super viewDidLoad];
    YourVc.navigationController.jp_linkViewHeight = 44.0f;
    self.navigationController.jp_linkView = YourLinkView;
}
```


#### Customize pop gesture distance

```objective-c
Objective-C:

self.navigationController.jp_interactivePopMaxAllowedInitialDistanceToLeftEdge = aValue;
```

#### Close pop gesture for single viewController

```objective-c
Objective-C:

self.navigationController.jp_closePopForAllViewController = YES;
```


#### Close pop gesture for all viewController

```objective-c
Objective-C:

self.navigationController.jp_closePopForAllViewController = YES;
```


Installation
------------

There are two ways to use JPNavigationController in your project:
- using CocoaPods
- by cloning the project into your repository

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries in your projects. See the [Get Started](http://cocoapods.org/#get_started) section for more details.

#### Podfile
```
platform :ios, '8.0'
target “YourProjectName” do
pod 'JPNavigationController', '~> 1.2.5'
end
```

## Licenses

All source code is licensed under the [MIT License](https://github.com/Chris-Pan/JPNavigationController/blob/master/LICENSE).


如果你在天朝
------------

框架支持为 UINavigationController 提供全屏 pop 和 push 手势支持, 并且你可以为每个控制器自定义 UINavigationBar, 注意, 每个控制器的 UINavigationBar 是互不干扰的. 实现基于AOP思想, 不会侵入你的项目.

## 特性

- [x] 全屏pop手势支持
- [x] 全屏push到绑定的控制器支持
- [x] 为每个控制器定制 UINavigationBar 支持(包括设置颜色和透明度)
- [x] 为每个控制器添加底部联动视图支持
- [x] 自定义pop手势范围支持(从屏幕最左侧开始计算宽度)
- [x] 为单个控制器关闭pop手势支持
- [x] 为所有控制器关闭pop手势支持


## 组件要求

- iOS 8.0 or later
- Xcode 8.0 or later


## 了解实现思路和源码解析

- 阅读我的简书文章 [[iOS]UINavigationController全屏pop之为每个控制器自定义UINavigationBar](http://www.jianshu.com/p/88bc827f0692)
- 阅读我的简书文章 [[iOS]UINavigationController全屏pop之为每个控制器添加底部联动视图](http://www.jianshu.com/p/3ed21414551a)
- 阅读我的简书文章 [[iOS]UINavigationController全屏pop之为控制器添加左滑push](http://www.jianshu.com/p/ff68b5e646fc)
- 下载我Github上的demo


## 联系

- 如果你发现了bug, 请帮我提交issue
- 如果你有好的建议, 请帮我提交issue
- 如果你想贡献代码, 请提交请求


## 安装

## 具体使用

#### 初始化

```objective-c
Objective-C:

#import <JPNavigationControllerKit.h>

JPNavigationController *nav = [[JPNavigationController alloc]initWithRootViewController:YourVc];
```

#### PushViewController

```objective-c
Objective-C:

[self.navigationController pushViewController:YourVc animated:YES];
```

#### PopToViewController

```objective-c
Objective-C:

[self.navigationController popViewControllerAnimated:YES];

[self.navigationController popToRootViewControllerAnimated:YES];


// 弹出到指定的控制器

// 方案A: 找到目标控制器, pop
JPSecondVC *second = nil;
NSArray *viewControllers = self.navigationController.jp_rootNavigationController.jp_viewControllers;
for (UIViewController *c in viewControllers) {
    if ([c isKindOfClass:[JPSecondVC class]]) {
        second = (JPSecondVC *)c;
        break;
    }
}

if (second) {
    [self.navigationController popToViewController:second animated:YES];
}


// 方案B: 使用 jp_popToViewControllerClassIs: animated:.
[self.navigationController jp_popToViewControllerClassIs:[JPSecondVC class] animated:YES];
```


#### 自定义 UINavigationBar

```objective-c
Objective-C:

// 隐藏导航条.
self.navigationController.navigationBarHidden = YES;

// 自定义 UINavigationBar 颜色
[self.navigationController.navigationBar setBackgroundImage:aImage forBarMetrics:UIBarMetricsDefault];

```

#### 添加push手势绑定控制器

```objective-c
Objective-C:

// 成为JPNavigationControllerDelegate协议的代理, 实现协议方法即可拥有左滑push功能.
self.navigationController.jp_delegate = self;

// 实现协议方法
-(void)jp_navigationControllerDidPushLeft{
    [self.navigationController pushViewController:YourVc animated:YES];
}
```

#### 添加底部联动视图支持

```objective-c
Objective-C:

// 你只需要在 viewDidLoad: 方法里把你的联动视图传给框架, 框架会制动帮你显示.
-(void)viewDidLoad{
    [super viewDidLoad];
    YourVc.navigationController.jp_linkViewHeight = 44.0f;
    self.navigationController.jp_linkView = YourLinkView;
}
```


#### 自定义 pop 手势响应范围

```objective-c
Objective-C:

self.navigationController.jp_interactivePopMaxAllowedInitialDistanceToLeftEdge = aValue;
```

#### 禁用单个控制器 pop 手势

```objective-c
Objective-C:

self.navigationController.jp_closePopForAllViewController = YES;
```


#### 禁用所有控制器 pop 手势

```objective-c
Objective-C:

self.navigationController.jp_closePopForAllViewController = YES;
```


集成到你的项目
------------

两种选择把框架集成到你的项目:
- 使用 CocoaPods
- 下载我的demo, 把'JPNavigationController'文件夹拽到你的项目中

### 使用 CocoaPods 安装

[CocoaPods](http://cocoapods.org/) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries in your projects. See the [Get Started](http://cocoapods.org/#get_started) section for more details.

#### Podfile
```
platform :ios, '8.0'
target “YourProjectName” do
pod 'JPNavigationController', '~> 1.2.5'
end
```

## 证书

All source code is licensed under the [MIT License](https://github.com/Chris-Pan/JPNavigationController/blob/master/LICENSE).

## 如果喜欢我的文章，请帮忙点个👍。


