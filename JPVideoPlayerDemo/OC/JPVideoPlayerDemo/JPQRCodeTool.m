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

#import "JPQRCodeTool.h"

const CGFloat JPQRCodeDrawPointMargin = 2;

@implementation JPQRCodeTool

+(nullable UIImage *)generateCodeForString:(nonnull NSString *)str withCorrectionLevel:(kQRCodeCorrectionLevel)corLevel SizeType:(kQRCodeSizeType)sizeType customSizeDelta:(CGFloat)cusDelta drawType:(kQRCodeDrawType)drawType gradientType:(kQRCodeGradientType)gradientType gradientColors:(nullable NSArray<UIColor *> *)colors{
    if (str.length==0)
        return nil;
    
    @autoreleasepool {
        CIImage *originalImg = [self createOriginalCIImageWithString:str withCorrectionLevel:corLevel];
        NSArray<NSArray *> *codePoints = [self getPixelsWithCIImage:originalImg];
        
        CGFloat extent = originalImg.extent.size.width; // 对应纠错率二维码矩阵点数宽度
        CGFloat size = 0;
        switch (sizeType) {
            case kQRCodeSizeTypeSmall:
                size = 10*extent;
                break;
            case kQRCodeSizeTypeNormal:
                size = 20*extent;
                break;
            case kQRCodeSizeTypeBig:
                size = 30*extent;
                break;
            case kQRCodeSizeTypeCustom:
                size = cusDelta*extent;
                break;
        }
        return [self drawWithCodePoints:codePoints andSize:size gradientColors:colors drawType:drawType gradientType:gradientType];
    }
}

// 创建原始二维码
+(CIImage *)createOriginalCIImageWithString:(NSString *)str withCorrectionLevel:(kQRCodeCorrectionLevel)corLevel{
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setDefaults];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    [filter setValue:data forKeyPath:@"inputMessage"];
    
    NSString *corLevelStr = nil;
    switch (corLevel) {
        case kQRCodeCorrectionLevelLow:
            corLevelStr = @"L";
            break;
        case kQRCodeCorrectionLevelNormal:
            corLevelStr = @"M";
            break;
        case kQRCodeCorrectionLevelSuperior:
            corLevelStr = @"Q";
            break;
        case kQRCodeCorrectionLevelHight:
            corLevelStr = @"H";
            break;
    }
    [filter setValue:corLevelStr forKey:@"inputCorrectionLevel"];
    
    CIImage *outputImage = [filter outputImage];
    return outputImage;
}

// 将 `CIImage` 转成 `CGImage`
+(CGImageRef)convertCIImage2CGImageForCIImage:(CIImage *)image{
    CGRect extent = CGRectIntegral(image.extent);
    
    size_t width = CGRectGetWidth(extent);
    size_t height = CGRectGetHeight(extent);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceGray();
    CGContextRef bitmapRef = CGBitmapContextCreate(nil, width, height, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaNone);
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef bitmapImage = [context createCGImage:image fromRect:extent];
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    CGContextScaleCTM(bitmapRef, 1, 1);
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    
    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapRef);
    CGContextRelease(bitmapRef);
    CGImageRelease(bitmapImage);
    
    return scaledImage;
}

// 将原始图片的所有点的色值保存到二维数组.
+(NSArray<NSArray *>*)getPixelsWithCIImage:(CIImage *)ciimg{
    NSMutableArray *pixels = [NSMutableArray array];
    
    // 将系统生成的二维码从 `CIImage` 转成 `CGImageRef`.
    CGImageRef imageRef = [self convertCIImage2CGImageForCIImage:ciimg];
    CGFloat width = CGImageGetWidth(imageRef);
    CGFloat height = CGImageGetHeight(imageRef);
    
    // 创建一个颜色空间.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 开辟一段 unsigned char 的存储空间，用 rawData 指向这段内存.
    // 每个 RGBA 色值的范围是 0-255，所以刚好是一个 unsigned char 的存储大小.
    // 每张图片有 height * width 个点，每个点有 RGBA 4个色值，所以刚好是 height * width * 4.
    // 这段代码的意思是开辟了 height * width * 4 个 unsigned char 的存储大小.
    unsigned char *rawData = (unsigned char *)calloc(height * width * 4, sizeof(unsigned char));
    
    // 每个像素的大小是 4 字节.
    NSUInteger bytesPerPixel = 4;
    // 每行字节数.
    NSUInteger bytesPerRow = width * bytesPerPixel;
    // 一个字节8比特
    NSUInteger bitsPerComponent = 8;
    
    // 将系统的二维码图片和我们创建的 rawData 关联起来，这样我们就可以通过 rawData 拿到指定 pixel 的内存地址.
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    for (int indexY = 0; indexY < height; indexY++) {
        NSMutableArray *tepArrM = [NSMutableArray array];
        for (int indexX = 0; indexX < width; indexX++) {
            // 取出每个 pixel 的 RGBA 值，保存到矩阵中.
            @autoreleasepool {
                NSUInteger byteIndex = bytesPerRow * indexY + indexX * bytesPerPixel;
                CGFloat red = (CGFloat)rawData[byteIndex];
                CGFloat green = (CGFloat)rawData[byteIndex + 1];
                CGFloat blue = (CGFloat)rawData[byteIndex + 2];
                
                BOOL shouldDisplay = red == 0 && green == 0 && blue == 0;
                [tepArrM addObject:@(shouldDisplay)];
                byteIndex += bytesPerPixel;
            }
        }
        [pixels addObject:[tepArrM copy]];
    }
    free(rawData);
    return [pixels copy];
}

+(UIImage *)drawWithCodePoints:(NSArray<NSArray *> *)codePoints andSize:(CGFloat)size gradientColors:(NSArray<UIColor *> *)colors drawType:(kQRCodeDrawType)drawType gradientType:(kQRCodeGradientType)gradientType{
    CGFloat imgWH = size;
    CGFloat delta = imgWH/codePoints.count;
    
    UIGraphicsBeginImageContext(CGSizeMake(imgWH, imgWH));
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    for (int indexY = 0; indexY < codePoints.count; indexY++) {
        for (int indexX = 0; indexX < codePoints[indexY].count; indexX++) {
            @autoreleasepool {
                BOOL shouldDisplay = [codePoints[indexY][indexX] boolValue];
                if (shouldDisplay) {
                    [self drawPointWithIndexX:indexX indexY:indexY delta:delta imgWH:imgWH colors:colors gradientType:gradientType drawType:drawType inContext:ctx];
                }
            }
        }
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

+(void)drawPointWithIndexX:(CGFloat)indexX indexY:(CGFloat)indexY delta:(CGFloat)delta imgWH:(CGFloat)imgWH colors:(NSArray<UIColor *> *)colors gradientType:(kQRCodeGradientType)gradientType drawType:(kQRCodeDrawType)drawType inContext:(CGContextRef)ctx{
    
    UIBezierPath *bezierPath;
    if (drawType==kQRCodeDrawTypeCircle) {
        CGFloat centerX = indexX*delta + 0.5*delta;
        CGFloat centerY = indexY*delta + 0.5*delta;
        CGFloat radius =  0.5*delta-JPQRCodeDrawPointMargin;
        CGFloat startAngle = 0;
        CGFloat endAngle = 2*M_PI;
        bezierPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(centerX, centerY) radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        
    }
    else if (drawType==kQRCodeDrawTypeSquare){
        bezierPath = [UIBezierPath bezierPathWithRect:CGRectMake(indexX*delta, indexY*delta, delta, delta)];
    }
    NSArray<UIColor *> *gradientColors = [self getGradientColorsWithStratPoint:CGPointMake(indexX*delta, indexY*delta) andEndPoint:CGPointMake((indexX+1)*delta, (indexY+1)*delta) totalWid:imgWH BetweenColors:colors gradientType:gradientType];
    
    [self drawLinearGradient:ctx path:bezierPath.CGPath startColor:[gradientColors firstObject].CGColor endColor:[gradientColors lastObject].CGColor gradientType:gradientType];
    CGContextSaveGState(ctx);
}

+(NSArray<UIColor *> *)getGradientColorsWithStratPoint:(CGPoint)startP andEndPoint:(CGPoint)endP totalWid:(CGFloat)totalWid BetweenColors:(NSArray<UIColor *> *)colors gradientType:(kQRCodeGradientType)gradientType{
    UIColor *color1 = colors.firstObject;
    UIColor *color2 = colors.lastObject;
    
    const CGFloat *components1 = CGColorGetComponents(color1.CGColor);
    const CGFloat *components2 = CGColorGetComponents(color2.CGColor);
    
    CGFloat red1 = components1[0];
    CGFloat green1 = components1[1];
    CGFloat blue1 = components1[2];
    
    CGFloat red2 = components2[0];
    CGFloat green2 = components2[1];
    CGFloat blue2 = components2[2];
    
    NSArray<UIColor *> *result = nil;
    switch (gradientType) {
        case kQRCodeGradientTypeHorizontal:
        {
            CGFloat startDelta = startP.x / totalWid;
            CGFloat endDelta = endP.x / totalWid;
            
            CGFloat startRed = (1-startDelta)*red1 + startDelta*red2;
            CGFloat startGreen = (1-startDelta)*green1 + startDelta*green2;
            CGFloat startBlue = (1-startDelta)*blue1 + startDelta*blue2;
            UIColor *startColor = [UIColor colorWithRed:startRed green:startGreen blue:startBlue alpha:1];
            
            CGFloat endRed = (1-endDelta)*red1 + endDelta*red2;
            CGFloat endGreen = (1-endDelta)*green1 + endDelta*green2;
            CGFloat endBlue = (1-endDelta)*blue1 + endDelta*blue2;
            UIColor *endColor = [UIColor colorWithRed:endRed green:endGreen blue:endBlue alpha:1];
            
            result = @[startColor, endColor];
        }
            break;
            
        case kQRCodeGradientTypeDiagonal:
        {
            CGFloat startDelta = [self calculateTarHeiForPoint:startP] / (totalWid * totalWid);
            CGFloat endDelta = [self calculateTarHeiForPoint:endP] / (totalWid * totalWid);
            
            CGFloat startRed = red1 + startDelta*(red2-red1);
            CGFloat startGreen = green1 + startDelta*(green2-green1);
            CGFloat startBlue = blue1 + startDelta*(blue2-blue1);
            UIColor *startColor = [UIColor colorWithRed:startRed green:startGreen blue:startBlue alpha:1];
            
            CGFloat endRed = red1 + endDelta*(red2-red1);
            CGFloat endGreen = green1 + endDelta*(green2-green1);
            CGFloat endBlue = blue1 + endDelta*(blue2-blue1);
            UIColor *endColor = [UIColor colorWithRed:endRed green:endGreen blue:endBlue alpha:1];
            
            result = @[startColor, endColor];
        }
            
        default:
            break;
    }
    
    return result;
}

+(CGFloat)calculateTarHeiForPoint:(CGPoint)point{
    CGFloat pointX = point.x;
    CGFloat pointY = point.y;
    
    CGFloat tarArcValue = pointX >= pointY ? M_PI_4-atan(pointY/pointX) : M_PI_4-atan(pointX/pointY);
    return cos(tarArcValue)*(pointX*pointX + pointY*pointY);
}

+(void)drawLinearGradient:(CGContextRef)context path:(CGPathRef)path startColor:(CGColorRef)startColor endColor:(CGColorRef)endColor gradientType:(kQRCodeGradientType)gradientType{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = {0.0, 1};
    
    NSArray *colors = @[(__bridge id) startColor, (__bridge id) endColor];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef) colors, locations);
    
    CGRect pathRect = CGPathGetBoundingBox(path);
    CGPoint startPoint = CGPointZero;
    CGPoint endPoint = CGPointZero;
    
    switch (gradientType) {
        case kQRCodeGradientTypeDiagonal:
        {
            startPoint = CGPointMake(CGRectGetMinX(pathRect), CGRectGetMinY(pathRect));
            endPoint = CGPointMake(CGRectGetMaxX(pathRect), CGRectGetMaxY(pathRect));
        }
            break;
        case kQRCodeGradientTypeHorizontal:
        {
            startPoint = CGPointMake(CGRectGetMinX(pathRect), CGRectGetMidY(pathRect));
            endPoint = CGPointMake(CGRectGetMaxX(pathRect), CGRectGetMidY(pathRect));
        }
            break;
        default:
            break;
    }
    
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@end
