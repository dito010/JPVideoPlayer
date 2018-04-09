/*
 * This file is part of the JPVideoPlayer package.
 * (c) NewPan <13246884282@163.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Click https://github.com/newyjp
 * or http://www.jianshu.com/users/e2f2d779c022/latest_articles to contact me.
 */

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, kQRCodeCorrectionLevel) {
    kQRCodeCorrectionLevelLow, // 低纠正率.
    kQRCodeCorrectionLevelNormal, // 一般纠正率.
    kQRCodeCorrectionLevelSuperior, // 较高纠正率.
    kQRCodeCorrectionLevelHight, // 高纠正率.
};

typedef NS_ENUM(NSInteger, kQRCodeSizeType) {
    kQRCodeSizeTypeSmall, // 10 倍对应纠错率二维码矩阵点数宽度(px).
    kQRCodeSizeTypeNormal, // 20 倍对应纠错率二维码矩阵点数宽度(px).
    kQRCodeSizeTypeBig, // 30 倍对应纠错率二维码矩阵点数宽度(px).
    kQRCodeSizeTypeCustom // 自定义对应纠错率二维码矩阵点数宽度倍数(px).
};

typedef NS_ENUM(NSInteger, kQRCodeDrawType) {
    kQRCodeDrawTypeSquare, // 正方形.
    kQRCodeDrawTypeCircle, // 圆.
};

typedef NS_ENUM(NSInteger, kQRCodeGradientType) {
    kQRCodeGradientTypeNone, // 纯色.
    kQRCodeGradientTypeHorizontal, // 水平渐变.
    kQRCodeGradientTypeDiagonal, // 对角线渐变.
};

@interface JPQRCodeTool : NSObject


/**
 * Generates a QRCoder image for given string.
 *
 * @param str            The string to the QRCoder image to generate.
 * @param corLevel       The correction level to the QRCoder image to generate.
 * @param sizeType       The size type of the QRCoder image to generate.
 * @param cusDelta       The size delta of the QRCoder image to generate if wanna to custom image
                           size(only need to pass if `sizeType` is passed `kQRCodeSizeTypeCustom`).
 * @param drawType       The draw type of QRCoder image to generate.
 * @param gradientType   The gradient type of QRCoder image to generate.
 * @param colors         The gradient colors of QRCoder image to generate.
 *
 * @return A token (@see JPVideoPlayerDownloadToken) that can be passed to -cancel: to cancel this operation.
 */
+(nullable UIImage *)generateCodeForString:(nonnull NSString *)str withCorrectionLevel:(kQRCodeCorrectionLevel)corLevel SizeType:(kQRCodeSizeType)sizeType customSizeDelta:(CGFloat)cusDelta drawType:(kQRCodeDrawType)drawType gradientType:(kQRCodeGradientType)gradientType gradientColors:(nullable NSArray<UIColor *> *)colors;

@end
