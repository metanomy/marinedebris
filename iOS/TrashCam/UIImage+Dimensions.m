//
//  UIImage+Dimensions.m
//  Rego
//
//  Created by Justin Driscoll on 1/6/12.
//  Copyright (c) 2012 MakaluMedia Inc. All rights reserved.
//


#import "UIImage+Dimensions.h"

@implementation UIImage (Dimensions)

- (UIImage *)resize:(CGSize)size quality:(CGInterpolationQuality)interpolationQuality
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetInterpolationQuality(context, interpolationQuality);
    [self drawInRect:CGRectMake(0.0, 0.0, size.width, size.height)];

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return newImage;
}

- (UIImage *)crop:(CGRect)rect
{
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 1.0f);

    CGRect drawRect = CGRectMake(-rect.origin.x, -rect.origin.y, self.size.width, self.size.height);
    [self drawInRect:drawRect];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (UIImage *)resizeAndCropToFit:(CGSize)size quality:(CGInterpolationQuality)interpolationQuality
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, interpolationQuality);

    CGSize newSize = [self sizeThatFills:size];
    CGFloat x = floor((size.width - newSize.width) / 2);
    CGFloat y = floor((size.height - newSize.height) / 2);

    CGRect drawRect = CGRectMake(x, y, newSize.width, newSize.height);
    [self drawInRect:drawRect];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    double ratio = fminf(size.width / self.size.width, size.height / self.size.height);
    CGFloat width = ceilf(self.size.width * ratio);
    CGFloat height = ceilf(self.size.height * ratio);

    width = width > size.width ? size.width : width;
    height = height > size.height ? size.height : height;

    return CGSizeMake(width, height);
}

- (CGSize)sizeThatFills:(CGSize)size
{
    double ratio = fmaxf(size.width / self.size.width, size.height / self.size.height);
    CGFloat width = floorf(self.size.width * ratio);
    CGFloat height = floorf(self.size.height * ratio);

    width = width < size.width ? size.width : width;
    height = height < size.height ? size.height : height;

    return CGSizeMake(width, height);
}

- (BOOL)isLandscape
{
    return self.size.width > self.size.height;
}

@end
