//
//  UIImage+Dimensions.h
//  Rego
//
//  Created by Justin Driscoll on 1/6/12.
//  Copyright (c) 2012 MakaluMedia Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Dimensions)

- (UIImage *)crop:(CGRect)rect;
- (UIImage *)resize:(CGSize)size quality:(CGInterpolationQuality)interpolationQuality;
- (UIImage *)resizeAndCropToFit:(CGSize)size quality:(CGInterpolationQuality)interpolationQuality;

- (CGSize)sizeThatFits:(CGSize)size;
- (CGSize)sizeThatFills:(CGSize)size;

- (BOOL)isLandscape;

@end
