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


#import <Foundation/Foundation.h>

@interface NSURL (StripQuery)

/*
 * Returns absolute string of URL with the query stripped out.
 * If there is no query, returns a copy of absolute string.
 */

- (NSString *)absoluteStringByStrippingQuery;

@end
