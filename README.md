# JPVideoPlayer

#### 仿微博首页列表视频自动播放，在主线程播放，不卡顿主线程，性能极佳。

### 主要的功能点：

#### 01.必须是边下边播。
#### 02.如果缓存好的视频是完整的，就要把这个视频保存起来，下次再次加载这个视频的时候，就先检查本地有没有缓存好的视频。这一点对于节省用户流量，提升用户体验很重要。
#### 03.不阻塞线程，不卡顿，滑动如丝顺滑，这是保证用户体验最重要的一点。
#### 04.当tableView滚动时，以什么样的策略，来确定究竟哪一个cell应该播放视频。

![JPVideoPlayer.png](http://upload-images.jianshu.io/upload_images/2122663-1c7d85122b7a61e2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 我为这个框架写了两篇文章，专门用来讲述我的实现思路：

### [[iOS]仿微博视频边下边播之封装播放器](http://www.jianshu.com/p/0d4588a7540f)

### [[iOS]仿微博视频边下边播之滑动TableView自动播放](http://www.jianshu.com/p/3946317760a6)

## 如果喜欢我的文章，请帮忙点个👍👍👍。
