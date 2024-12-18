//
//  CYRKeyboardButtonView.m
//
//  Created by Illya Busigin on 7/19/14.
//  Copyright (c) 2014 Cyrillian, Inc.
//  Portions Copyright (c) 2013 Nigel Timothy Barber (TurtleBezierPath)
//
//  Distributed under MIT license.
//  Get the latest version from here:
//
//  https://github.com/illyabusigin/CYRKeyboardButton
//
// The MIT License (MIT)
//
// Copyright (c) 2014 Cyrillian, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "CYRKeyboardButtonView.h"
#import "CYRKeyboardButton.h"
#import "TurtleBezierPath.h"

@interface CYRKeyboardButtonView ()

@property (nonatomic, weak) CYRKeyboardButton *button;
@property (nonatomic, assign) CYRKeyboardButtonViewType type;
@property (nonatomic, assign) CYRKeyboardButtonPosition expandedPosition;
@property (nonatomic, strong) NSMutableArray *inputOptionRects;
@property (nonatomic, strong, nullable) UISelectionFeedbackGenerator *selectionFeedbackGenerator;

@end

@implementation CYRKeyboardButtonView

#pragma mark - UIView

- (instancetype)initWithKeyboardButton:(CYRKeyboardButton *)button type:(CYRKeyboardButtonViewType)type
{
    self = [super initWithFrame:UIScreen.mainScreen.bounds];
    if (self) {
        _button = button;
        _type = type;
        _selectedInputIndex = NSNotFound;
        _selectionFeedbackGenerator = [UISelectionFeedbackGenerator new];
        [_selectionFeedbackGenerator prepare];
        
        self.heightReduction = 0.f;
        self.useNarrowerOptionWidth = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        
        if (button.position != CYRKeyboardButtonPositionInner) {
            _expandedPosition = button.position;
        } else {
            // Determine the position
            CGFloat leftPadding = CGRectGetMinX(button.frame);
            CGFloat rightPadding = CGRectGetMaxX(button.superview.frame) - CGRectGetMaxX(button.frame);
            
            _expandedPosition = (leftPadding > rightPadding ? CYRKeyboardButtonPositionLeft : CYRKeyboardButtonPositionRight);
        }
    }
    
    return self;
}

- (void)didMoveToSuperview
{
    if (_type == CYRKeyboardButtonViewTypeExpanded) {
        [self determineExpandedKeyGeometries];
    }
}

#pragma mark - Public

- (void)selectInputAt:(NSUInteger)index {
    if ( index == (NSUInteger)NSNotFound || index > (NSUInteger)NSIntegerMax )
        [NSException raise:NSInvalidArgumentException format:@"invalid index: %lu", (unsigned long)index];

    if ( index != (NSUInteger)_selectedInputIndex ) {
        _selectedInputIndex = index;
        [self setNeedsDisplay];
        [_selectionFeedbackGenerator selectionChanged];
        [_selectionFeedbackGenerator prepare];
    }
}

- (void)updateSelectedInputIndexForPoint:(CGPoint)point
{
    __block NSInteger selectedInputIndex = 0;
    
    CGPoint location = [self convertRect:CGRectMake(point.x, point.y, 0, 0) fromView:nil].origin;
    CGRect bounds = self.expandedInputViewPath.bounds;
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat width = CGRectGetWidth(bounds);
    CGRect touchBoundsRect = CGRectMake(CGRectGetMinX(bounds) - height/2,
                                        CGRectGetMinY(bounds) - height/2,
                                        height + width,
                                        height + height);
    BOOL inBounds = CGRectContainsPoint(touchBoundsRect, location);

    if ( inBounds ) {
        CGRect leftTouchBounds, rightTouchBounds;
        NSArray * inputOptionRects = self.inputOptionRects;
        NSUInteger count = inputOptionRects.count;
        
        CGRectDivide(touchBoundsRect, &leftTouchBounds, &rightTouchBounds, width / 2, CGRectMinXEdge);
        
        selectedInputIndex = CGRectContainsPoint(_expandedPosition == CYRKeyboardButtonPositionRight ? leftTouchBounds : rightTouchBounds, location) ? 0 : count - 1;
        
        [inputOptionRects enumerateObjectsUsingBlock:^(NSValue *rectValue, NSUInteger idx, BOOL *stop) {
            CGRect keyRect = [rectValue CGRectValue];
            CGRect infiniteKeyRect = CGRectMake(CGRectGetMinX(keyRect), 0, CGRectGetWidth(keyRect), NSIntegerMax);
            infiniteKeyRect = CGRectInset(infiniteKeyRect, -3, 0);
            
            if (CGRectContainsPoint(infiniteKeyRect, location)) {
                selectedInputIndex = idx;
                *stop = YES;
            }
        }];
    }

    if ( selectedInputIndex != NSNotFound )
        [self selectInputAt:selectedInputIndex];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    switch (_type) {
        case CYRKeyboardButtonViewTypeInput:
            [self drawInputView:rect];
            break;
            
        case CYRKeyboardButtonViewTypeExpanded:
            [self drawExpandedInputView:rect];
            break;
            
        default:
            break;
    }
}

- (void)drawInputView:(CGRect)rect
{
    // Generate the overlay
    UIBezierPath *bezierPath = [self inputViewPath];
    NSString *inputString = self.button.input;
    
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Overlay path & shadow
    {
        //// Shadow Declarations
        UIColor* shadow = [[UIColor blackColor] colorWithAlphaComponent: 0.5];
        CGSize shadowOffset = CGSizeMake(0, 0.5);
        CGFloat shadowBlurRadius = 2;
        
        //// Rounded Rectangle Drawing
        CGContextSaveGState(context);
        if (self.button.showShadow) {
            CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
        }
        [self.button.borderColor setStroke];
        bezierPath.lineWidth = self.button.borderWidth;
        [bezierPath stroke];
        
        UIColor* color = self.button.keyColor;
        UIColor* bottomColor = self.button.keyBottomColor;
        if (!bottomColor) {
            [color setFill];
            [bezierPath fill];
        } else {
            [bezierPath addClip];
            
            CGColorSpaceRef baseSpace = CGColorSpaceCreateDeviceRGB();
            NSArray * colors = @[ (__bridge id)color.CGColor, (__bridge id)bottomColor.CGColor ];
            CGGradientRef gradient = CGGradientCreateWithColors(baseSpace, (__bridge CFArrayRef)colors, NULL);
            CGColorSpaceRelease(baseSpace), baseSpace = NULL;
            
            CGPoint startPoint = CGPointMake(CGRectGetMidX(bezierPath.bounds), CGRectGetMinY(bezierPath.bounds));
            CGPoint endPoint = CGPointMake(CGRectGetMidX(bezierPath.bounds), CGRectGetMaxY(bezierPath.bounds));

            CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
            CGGradientRelease(gradient), gradient = NULL;
        }
        
        CGContextRestoreGState(context);
    }
        
    // Text drawing
    {
        UIColor *stringColor = self.button.keyTextColor;
        
        CGRect stringRect = bezierPath.bounds;
        
        if (self.button.inputOptions.count > 0 && self.button.font.pointSize < 22.f) {
            stringRect.origin.y += self.button.font.pointSize;
        }
        
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.alignment = NSTextAlignmentCenter;
        
        // use button font with 2x size and Light weight:
        UIFontDescriptor * fontDescriptor = self.button.font.fontDescriptor;
        NSMutableDictionary<UIFontDescriptorTraitKey, id> * fontTraits = [NSMutableDictionary<UIFontDescriptorTraitKey, id> dictionaryWithDictionary:fontDescriptor.fontAttributes[UIFontDescriptorTraitsAttribute] ?: @{}];
        fontTraits[UIFontWeightTrait] = @(UIFontWeightLight);
        fontDescriptor = [fontDescriptor fontDescriptorByAddingAttributes:@{
            UIFontDescriptorTraitsAttribute : fontTraits,
        }];
        UIFont* font = [UIFont fontWithDescriptor:fontDescriptor size:self.button.font.pointSize * 2];
        
        NSAttributedString *attributedString = [[NSAttributedString alloc]
                                                initWithString:inputString
                                                attributes:
                                                @{NSFontAttributeName : font, NSForegroundColorAttributeName : stringColor, NSParagraphStyleAttributeName : p}];
        [attributedString drawInRect:stringRect];
    }
}

- (void)drawExpandedInputView:(CGRect)rect
{
    // Generate the overlay
    UIBezierPath *bezierPath = [self expandedInputViewPath];
        
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Overlay path & shadow
    {
        CGFloat shadowAlpha = 0;
        CGSize shadowOffset = CGSizeZero;
        
        switch ([UIDevice currentDevice].userInterfaceIdiom) {
            case UIUserInterfaceIdiomPhone:
                shadowAlpha = 0.5;
                shadowOffset = CGSizeMake(0, 0.5);
                break;
                
            case UIUserInterfaceIdiomPad:
                shadowAlpha = 0.25;
                shadowOffset = CGSizeZero;
                break;
                
            default:
                break;
        }
        
        //// Shadow Declarations
        UIColor* shadow = [[UIColor blackColor] colorWithAlphaComponent: shadowAlpha];
        CGFloat shadowBlurRadius = 2;
        
        //// Rounded Rectangle Drawing
        CGContextSaveGState(context);
        if (self.button.showShadow) {
            CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
        }
        [self.button.borderColor setStroke];
        bezierPath.lineWidth = self.button.borderWidth;
        [bezierPath stroke];
        
        UIColor* color = self.button.keyColor;
        UIColor* bottomColor = self.button.keyBottomColor;
        if (!bottomColor) {
            [color setFill];
            [bezierPath fill];
        } else {
            [bezierPath addClip];
            
            CGColorSpaceRef baseSpace = CGColorSpaceCreateDeviceRGB();
            NSArray * colors = @[ (__bridge id)color.CGColor, (__bridge id)bottomColor.CGColor ];
            CGGradientRef gradient = CGGradientCreateWithColors(baseSpace, (__bridge CFArrayRef)colors, NULL);
            CGColorSpaceRelease(baseSpace), baseSpace = NULL;
            
            CGPoint startPoint = CGPointMake(CGRectGetMidX(bezierPath.bounds), CGRectGetMinY(bezierPath.bounds));
            CGPoint endPoint = CGPointMake(CGRectGetMidX(bezierPath.bounds), CGRectGetMaxY(bezierPath.bounds));

            CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
            CGGradientRelease(gradient), gradient = NULL;
        }
        
        CGContextRestoreGState(context);
    }
        
    [self drawExpandedInputViewOptions];
}

- (void)drawExpandedInputViewOptions
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShadowWithColor(context, CGSizeZero, 0, [[UIColor clearColor] CGColor]);
    CGContextSaveGState(context);
    
    NSArray *inputOptions = self.button.inputOptionsDisplayNames ?: self.button.inputOptions;
    
    [inputOptions enumerateObjectsUsingBlock:^(NSString *optionString, NSUInteger idx, BOOL *stop) {
        CGRect optionRect = [self.inputOptionRects[idx] CGRectValue];
        
        BOOL selected = (idx == (NSUInteger)self.selectedInputIndex);

        if (selected) {
            // Draw selection background
            if (self.button.style == CYRKeyboardButtonStylePhone) {
                optionRect.origin.y += self.heightReduction / 2;
                optionRect.size.height -= self.heightReduction;
            }
            UIBezierPath *roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect:optionRect cornerRadius:4];
            
            [self.tintColor setFill];
            [roundedRectanglePath fill];
        }
        
        // Draw the text
        UIColor *stringColor = (selected ? [UIColor whiteColor] : self.button.keyTextColor);
        CGSize stringSize = [optionString sizeWithAttributes:@{NSFontAttributeName : self.button.inputOptionsFont}];
        CGRect stringRect = CGRectMake(
                                       CGRectGetMidX(optionRect) - stringSize.width / 2, CGRectGetMidY(optionRect) - stringSize.height / 2, stringSize.width, stringSize.height);
        
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.alignment = NSTextAlignmentCenter;
        
        NSAttributedString *attributedString = [[NSAttributedString alloc]
                                                initWithString:optionString
                                                attributes:
                                                @{NSFontAttributeName : self.button.inputOptionsFont,
                                                  NSForegroundColorAttributeName : stringColor,
                                                  NSParagraphStyleAttributeName : p}];
        [attributedString drawInRect:stringRect];
    }];
    
    CGContextRestoreGState(context);
}

#pragma mark - Internal

- (UIBezierPath *)inputViewPath
{
    CGRect keyRect = [self convertRect:self.button.frame fromView:self.button.superview];
    
    UIEdgeInsets insets = UIEdgeInsetsMake(7, 13, 7, 13);
    CGFloat upperWidth = CGRectGetWidth(_button.frame) + insets.left + insets.right;
    CGFloat lowerWidth = CGRectGetWidth(_button.frame);
    CGFloat majorRadius = 10.f;
    CGFloat minorRadius = 4.f;
    
    CGFloat bubbleHeight = CGRectGetHeight(keyRect) - self.heightReduction;
    CGFloat armHeight = CGRectGetHeight(keyRect) - self.heightReduction;
    
    TurtleBezierPath *path = [TurtleBezierPath new];
    [path home];
    path.lineWidth = 0;
    path.lineCapStyle = kCGLineCapRound;
    
    switch (self.button.position) {
        case CYRKeyboardButtonPositionInner:
        {
            [path rightArc:majorRadius turn:90]; // #1
            [path forward:upperWidth - 2 * majorRadius]; // #2 top
            [path rightArc:majorRadius turn:90]; // #3
            [path forward:bubbleHeight - 2 * majorRadius + insets.top + insets.bottom]; // #4 right big
            [path rightArc:majorRadius turn:48]; // #5
            [path forward:8.5f];
            [path leftArc:majorRadius turn:48]; // #6
            [path forward:armHeight - 8.5f + 1];
            [path rightArc:minorRadius turn:90];
            [path forward:lowerWidth - 2 * minorRadius]; //  lowerWidth - 2 * minorRadius + 0.5f
            [path rightArc:minorRadius turn:90];
            [path forward:armHeight - 2 * minorRadius];
            [path leftArc:majorRadius turn:48];
            [path forward:8.5f];
            [path rightArc:majorRadius turn:48];
            [path closePath];
            
            CGFloat offsetX = 0, offsetY = 0;
            CGRect pathBoundingBox = path.bounds;
            
            offsetX = CGRectGetMidX(keyRect) - CGRectGetMidX(path.bounds);
            offsetY = CGRectGetMaxY(keyRect) - CGRectGetHeight(pathBoundingBox) + 10;
            
            [path applyTransform:CGAffineTransformMakeTranslation(offsetX, offsetY)];
        }
            break;
        
        case CYRKeyboardButtonPositionLeft:
        {
            [path rightArc:majorRadius turn:90]; // #1
            [path forward:upperWidth - 2 * majorRadius]; // #2 top
            [path rightArc:majorRadius turn:90]; // #3
            [path forward:bubbleHeight - 2 * majorRadius + insets.top + insets.bottom]; // #4 right big
            [path rightArc:majorRadius turn:45]; // #5
            [path forward:28]; // 6
            [path leftArc:majorRadius turn:45]; // #7
            [path forward:armHeight - 26 + (insets.left + insets.right) / 4]; // #8
            [path rightArc:minorRadius turn:90]; // 9
            [path forward:path.currentPoint.x - minorRadius]; // 10
            [path rightArc:minorRadius turn:90]; // 11
            [path closePath];
            
            CGFloat offsetX = 0, offsetY = 0;
            CGRect pathBoundingBox = path.bounds;
            
            offsetX = CGRectGetMaxX(keyRect) - CGRectGetWidth(path.bounds);
            offsetY = CGRectGetMaxY(keyRect) - CGRectGetHeight(pathBoundingBox) - CGRectGetMinY(path.bounds);

            [path applyTransform:CGAffineTransformTranslate(CGAffineTransformMakeScale(-1, 1), -offsetX - CGRectGetWidth(path.bounds), offsetY)];
        }
            break;
            
        case CYRKeyboardButtonPositionRight:
        {
            [path rightArc:majorRadius turn:90]; // #1
            [path forward:upperWidth - 2 * majorRadius]; // #2 top
            [path rightArc:majorRadius turn:90]; // #3
            [path forward:bubbleHeight - 2 * majorRadius + insets.top + insets.bottom]; // #4 right big
            [path rightArc:majorRadius turn:45]; // #5
            [path forward:28]; // 6
            [path leftArc:majorRadius turn:45]; // #7
            [path forward:armHeight - 26 + (insets.left + insets.right) / 4]; // #8
            [path rightArc:minorRadius turn:90]; // 9
            [path forward:path.currentPoint.x - minorRadius]; // 10
            [path rightArc:minorRadius turn:90]; // 11
            [path closePath];
            
            CGFloat offsetX = 0, offsetY = 0;
            CGRect pathBoundingBox = path.bounds;
            
            offsetX = CGRectGetMinX(keyRect);
            offsetY = CGRectGetMaxY(keyRect) - CGRectGetHeight(pathBoundingBox) - CGRectGetMinY(path.bounds);
            
            [path applyTransform:CGAffineTransformMakeTranslation(offsetX, offsetY)];
        }
            break;
            
        default:
            break;
    }

    return path;
}

- (UIBezierPath *)expandedInputViewPath
{
    CGRect keyRect = [self convertRect:self.button.frame fromView:self.button.superview];
    
    UIEdgeInsets insets = UIEdgeInsetsMake(7, 13, 7, 13);
    CGFloat margin = 7.f;
    CGFloat upperWidth = insets.left + insets.right + self.button.inputOptions.count * CGRectGetWidth(keyRect) + margin * (self.button.inputOptions.count - 1) - margin/2;
    CGFloat lowerWidth = CGRectGetWidth(_button.frame);
    CGFloat majorRadius = 10.f;
    CGFloat minorRadius = 4.f;
    
    CGFloat bubbleHeight = CGRectGetHeight(keyRect) - self.heightReduction;
    CGFloat armHeight = CGRectGetHeight(keyRect) - self.heightReduction;
    
    TurtleBezierPath *path = [TurtleBezierPath new];
    [path home];
    path.lineWidth = 0;
    path.lineCapStyle = kCGLineCapRound;
    
    CGFloat offsetX = 0, offsetY = 0;
    
    switch (_expandedPosition) {
        case CYRKeyboardButtonPositionRight:
        {
            switch (self.button.style) {
                case CYRKeyboardButtonStylePhone:
                {
                    [path rightArc:majorRadius turn:90]; // #1
                    [path forward:upperWidth - 2 * majorRadius]; // #2 top
                    [path rightArc:majorRadius turn:90]; // #3
                    [path forward:bubbleHeight - 2 * majorRadius + insets.top + insets.bottom - 3]; // #4 right big
                    [path rightArc:majorRadius turn:90]; // #5
                    [path forward:path.currentPoint.x - (CGRectGetWidth(keyRect) + 2 * majorRadius + 3)];
                    [path leftArc:majorRadius turn:90]; // #6
                    [path forward:armHeight - minorRadius];
                    [path rightArc:minorRadius turn:90];
                    [path forward:lowerWidth - 2 * minorRadius]; //  lowerWidth - 2 * minorRadius + 0.5f
                    [path rightArc:minorRadius turn:90];
                    [path forward:armHeight - 2 * minorRadius];
                    [path leftArc:majorRadius turn:48];
                    [path forward:8.5f];
                    [path rightArc:majorRadius turn:48];
                    [path closePath];
                    
                    offsetX = CGRectGetMaxX(keyRect) - CGRectGetWidth(keyRect) - insets.left;
                    offsetY = CGRectGetMaxY(keyRect) - CGRectGetHeight(path.bounds) + 10;
                    
                    [path applyTransform:CGAffineTransformMakeTranslation(offsetX, offsetY)];
                }
                    break;
                    
                case CYRKeyboardButtonStyleTablet:
                {
                    CGRect firstRect = [self.inputOptionRects[0] CGRectValue];
                    
                    path = (id)[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, CGRectGetWidth(firstRect) * self.button.inputOptions.count + 12, CGRectGetHeight(firstRect) + 12)
                                                          cornerRadius:6];
                    
                    offsetX = CGRectGetMinX(keyRect);
                    offsetY = CGRectGetMinY(firstRect) - 6;
                    
                    [path applyTransform:CGAffineTransformMakeTranslation(offsetX, offsetY)];
                    
                }
                    break;
                    
                default:
                    break;
            }
            
            
        }
            break;
            
        case CYRKeyboardButtonPositionLeft:
        {
            switch (self.button.style) {
                case CYRKeyboardButtonStylePhone:
                {
                    [path rightArc:majorRadius turn:90]; // #1
                    [path forward:upperWidth - 2 * majorRadius]; // #2 top
                    [path rightArc:majorRadius turn:90]; // #3
                    [path forward:bubbleHeight - 2 * majorRadius + insets.top + insets.bottom - 3]; // #4 right big
                    
                    [path rightArc:majorRadius turn:48];
                    [path forward:8.5f];
                    [path leftArc:majorRadius turn:48];
                    
                    [path forward:armHeight - minorRadius];
                    [path rightArc:minorRadius turn:90];
                    [path forward:lowerWidth - 2 * minorRadius]; //  lowerWidth - 2 * minorRadius + 0.5f
                    [path rightArc:minorRadius turn:90];
                    [path forward:armHeight - 2 * minorRadius];
                    
                    [path leftArc:majorRadius turn:90]; // #5
                    [path forward:path.currentPoint.x - majorRadius];
                    [path rightArc:majorRadius turn:90]; // #6
                    [path closePath];
                    
                    offsetX = CGRectGetMaxX(keyRect) - CGRectGetWidth(path.bounds) + insets.left;
                    offsetY = CGRectGetMaxY(keyRect) - CGRectGetHeight(path.bounds) + 10;
                    
                    [path applyTransform:CGAffineTransformMakeTranslation(offsetX, offsetY)];

                }
                    break;
                    
                case CYRKeyboardButtonStyleTablet:
                {
                    CGRect firstRect = [self.inputOptionRects[0] CGRectValue];
                    
                    path = (id)[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, CGRectGetWidth(firstRect) * self.button.inputOptions.count + 12, CGRectGetHeight(firstRect) + 12)
                                                          cornerRadius:6];
                    
                    offsetX = CGRectGetMaxX(keyRect) - CGRectGetWidth(path.bounds);
                    offsetY = CGRectGetMinY(firstRect) - 6;
                    
                    [path applyTransform:CGAffineTransformMakeTranslation(offsetX, offsetY)];
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
    
    return path;
}

- (void)determineExpandedKeyGeometries
{
    CGRect keyRect = [self convertRect:self.button.frame fromView:self.button.superview];
    
    if (self.useNarrowerOptionWidth) {
        keyRect.size.width /= 2;
    }
    __block NSMutableArray *inputOptionRects = [NSMutableArray arrayWithCapacity:self.button.inputOptions.count];
    
    CGFloat offset = 0;
    CGFloat spacing = 0;
    
    __block CGRect optionRect = CGRectZero;
    
    switch (self.button.style) {
        case CYRKeyboardButtonStylePhone:
            offset = CGRectGetWidth(keyRect);
            spacing = 6;
            optionRect = CGRectOffset(CGRectInset(keyRect, 0, 0.5), 0, -((CGRectGetHeight(keyRect) - self.heightReduction) + 15));
            break;
            
        case CYRKeyboardButtonStyleTablet:
            spacing = 0;
            optionRect = CGRectOffset(CGRectInset(keyRect, 6, 6), 0, -((CGRectGetHeight(keyRect) - self.heightReduction) + 3));
            optionRect.size.height -= self.heightReduction;
            offset = CGRectGetWidth(optionRect);
            break;
            
        default:
            break;
    }
    
    [self.button.inputOptions enumerateObjectsUsingBlock:^(NSString *option, NSUInteger idx, BOOL *stop) {
        
        [inputOptionRects addObject:[NSValue valueWithCGRect:optionRect]];
        
        // Offset the option rect
        switch (self.expandedPosition) {
            case CYRKeyboardButtonPositionRight:
                optionRect = CGRectOffset(optionRect, +(offset + spacing), 0);
                break;
                
            case CYRKeyboardButtonPositionLeft:
                optionRect = CGRectOffset(optionRect, -(offset + spacing), 0);
                break;
                
            default:
                break;
        }
    }];
    
    self.inputOptionRects = inputOptionRects;
}

@end
