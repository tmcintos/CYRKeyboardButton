//
//  CYRKeyboardButton.m
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

#import "CYRKeyboardButton.h"
#import "CYRKeyboardButtonView.h"

NSString *const CYRKeyboardButtonPressedNotification = @"CYRKeyboardButtonPressedNotification";
NSString *const CYRKeyboardButtonDidShowExpandedInputNotification = @"CYRKeyboardButtonDidShowExpandedInputNotification";
NSString *const CYRKeyboardButtonDidHideExpandedInputNotification = @"CYRKeyboardButtonDidHideExpandedInputNotification";
NSString *const CYRKeyboardButtonKeyPressedKey = @"CYRKeyboardButtonKeyPressedKey";

#define kMinimumInputViewShowingTime 0.125f

@interface CYRKeyboardButton () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIStackView* stackView;
@property (nonatomic, strong) UILabel *alternateInputLabel;
@property (nonatomic, strong) UILabel *inputLabel;
@property (nonatomic, strong) CYRKeyboardButtonView *buttonView;
@property (nonatomic, strong) CYRKeyboardButtonView *expandedButtonView;

@property (nonatomic, assign) CYRKeyboardButtonPosition position;
@property (nonatomic, assign) BOOL useAlternateInput;
@property (nonatomic, assign) CGFloat alternateInputLabelAlpha;

@property (nonatomic, assign) NSTimeInterval lastTouchDown;

// Input options state
@property (nonatomic, strong) UILongPressGestureRecognizer *optionsViewRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

// Internal style
@property (nonatomic, assign) CGFloat keyCornerRadius UI_APPEARANCE_SELECTOR;

@end

@implementation CYRKeyboardButton

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    switch ([UIDevice currentDevice].userInterfaceIdiom) {
        case UIUserInterfaceIdiomPhone:
            _style = CYRKeyboardButtonStylePhone;
            break;
            
        case UIUserInterfaceIdiomPad:
            _style = CYRKeyboardButtonStyleTablet;
            break;
            
        default:
            break;
    }
    
    // Default appearance
    _alternateFont = [UIFont systemFontOfSize:13.f];
    _font = [UIFont systemFontOfSize:22.f];
    _inputOptionsFont = [UIFont systemFontOfSize:24.f];
    _keyColor = [UIColor whiteColor];
    _keyTextColor = [UIColor blackColor];
    _keyShadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.3];
    _keyHighlightedColor = [UIColor colorWithRed:213/255.f green:214/255.f blue:216/255.f alpha:1];
    _useAlternateInput = NO;
    _alternateInputLabelAlpha = 0.2f;
    
    self.trackingMarginInset = 0.f;
    _showShadow = YES;
    _borderWidth = 0;
    _borderColor = [UIColor clearColor];
    
    // Styling
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = NO;
    self.layer.masksToBounds = NO;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    
    // State handling
    [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    
    UIStackView* stackView = [[UIStackView alloc] initWithFrame:self.bounds];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.distribution = UIStackViewDistributionEqualSpacing;
    stackView.spacing = 0;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.userInteractionEnabled = NO;
    
    _stackView = stackView;
    [self addSubview:_stackView];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:_stackView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:_stackView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0]];
    
    if (_style == CYRKeyboardButtonStyleTablet) {
        // Input label
        UILabel *alternateInputLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        alternateInputLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        alternateInputLabel.textAlignment = NSTextAlignmentCenter;
        alternateInputLabel.backgroundColor = [UIColor clearColor];
        alternateInputLabel.userInteractionEnabled = NO;
        alternateInputLabel.textColor = _keyTextColor;
        alternateInputLabel.alpha = _alternateInputLabelAlpha;
        alternateInputLabel.font = _alternateFont;

        _alternateInputLabel = alternateInputLabel;
        [_stackView addArrangedSubview:_alternateInputLabel];
    }
    
    // Input label
    UILabel *inputLabel = [[UILabel alloc] initWithFrame:self.bounds];
    inputLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    inputLabel.textAlignment = NSTextAlignmentCenter;
    inputLabel.backgroundColor = [UIColor clearColor];
    inputLabel.userInteractionEnabled = NO;
    inputLabel.textColor = _keyTextColor;
    inputLabel.font = _font;
    
    _inputLabel = inputLabel;
    [_stackView addArrangedSubview:_inputLabel];
    
    [self updateDisplayStyle];
}

- (void)didMoveToSuperview
{
    [self updateButtonPosition];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self setNeedsDisplay];
    
    [self updateButtonPosition];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect area = CGRectInset(self.bounds, -self.trackingMarginInset, -self.trackingMarginInset);
    return CGRectContainsPoint(area, point);
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // Only allow simulateous recognition with our internal recognizers
    return (gestureRecognizer == _panGestureRecognizer || gestureRecognizer == _optionsViewRecognizer) &&
    (otherGestureRecognizer == _panGestureRecognizer || otherGestureRecognizer == _optionsViewRecognizer);
}

#pragma mark - Overrides

- (NSString *)description
{
    NSString *description = [NSString stringWithFormat:@"<%@ %p>; frame = %@; input = %@;%@ inputOptions = %@",
                             NSStringFromClass([self class]),
                             self,
                             NSStringFromCGRect(self.frame),
                             self.input,
                             self.alternateInput ? [NSString stringWithFormat:@" alt = %@;", self.alternateInput] : @"",
                             self.inputOptions];
    
    return description;
}

- (void)setAlternateInput:(NSString *)alternateInput {
    [self willChangeValueForKey:NSStringFromSelector(@selector(alternateInput))];
    _alternateInput = alternateInput;
    [self didChangeValueForKey:NSStringFromSelector(@selector(alternateInput))];
    
    _alternateInputLabel.text = alternateInput;
    [_alternateInputLabel sizeToFit];
    [self setupInputOptionsConfiguration];
}

- (void)setInput:(NSString *)input
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(input))];
    _input = input;
    [self didChangeValueForKey:NSStringFromSelector(@selector(input))];
    
    _inputLabel.text = _input;
    [_inputLabel sizeToFit];
}

- (void)setInput:(NSString*)input withText:(NSString*)text {
    self.input = input;
    _inputLabel.text = text;
    [_inputLabel sizeToFit];
}

- (void)enableTrackpadMode:(BOOL)enable {
    _inputLabel.alpha = enable ? 0 : 1.f;
    _alternateInputLabel.alpha = enable ? 0 : _alternateInputLabelAlpha;
}

- (void)setInputOptions:(NSArray *)inputOptions
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(inputOptions))];
    _inputOptions = inputOptions;
    [self didChangeValueForKey:NSStringFromSelector(@selector(inputOptions))];
    
    [self setupInputOptionsConfiguration];
}

- (void)setStyle:(CYRKeyboardButtonStyle)style
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(style))];
    _style = style;
    [self didChangeValueForKey:NSStringFromSelector(@selector(style))];
    
    [self updateDisplayStyle];
}

- (void)setKeyTextColor:(UIColor *)keyTextColor
{
    if (_keyTextColor != keyTextColor) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(keyTextColor))];
        _keyTextColor = keyTextColor;
        [self didChangeValueForKey:NSStringFromSelector(@selector(keyTextColor))];
        
        _inputLabel.textColor = keyTextColor;
        _alternateInputLabel.textColor = keyTextColor;
    }
}

- (void)setFont:(UIFont *)font
{
    if (_font != font) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(font))];
        _font = font;
        [self didChangeValueForKey:NSStringFromSelector(@selector(font))];
        
        _inputLabel.font = font;
    }
}

- (void)setAlternateFont:(UIFont *)alternateFont
{
    if (_alternateFont != alternateFont) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(font))];
        _alternateFont = alternateFont;
        [self didChangeValueForKey:NSStringFromSelector(@selector(font))];
        
        _alternateInputLabel.font = _alternateFont;
    }
}

- (void)setTextInput:(id<UITextInput>)textInput
{
    NSAssert([textInput conformsToProtocol:@protocol(UITextInput)], @"<CYRKeyboardButton> The text input object must conform to the UITextInput protocol!");
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(textInput))];
    _textInput = textInput;
    [self didChangeValueForKey:NSStringFromSelector(@selector(textInput))];
}

#pragma mark - Internal - UI

- (void)showInputView
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideInputAndExpandedViews) object:nil];
    
    if (_style == CYRKeyboardButtonStylePhone) {
        [self hideInputView];
        
        self.buttonView = [[CYRKeyboardButtonView alloc] initWithKeyboardButton:self type:CYRKeyboardButtonViewTypeInput];
        self.buttonView.heightReduction = self.calloutHeightReduction;
        
        [self.window addSubview:self.buttonView];
    } else {
        self.highlighted = YES;
        [self setNeedsDisplay];
    }
    
}

- (void)showExpandedInputView:(UILongPressGestureRecognizer *)recognizer
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideInputAndExpandedViews) object:nil];
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (self.expandedButtonView == nil) {
            CYRKeyboardButtonView *expandedButtonView = [[CYRKeyboardButtonView alloc] initWithKeyboardButton:self type:CYRKeyboardButtonViewTypeExpanded];
            
            NSUInteger index = [_inputOptions indexOfObject:_input];
            
            [expandedButtonView selectInputAt:index != NSNotFound ? index : -1];
            expandedButtonView.heightReduction = self.calloutHeightReduction;
            expandedButtonView.useNarrowerOptionWidth = self.useNarrowerOptionWidth;
            
            [self.window addSubview:expandedButtonView];
            self.expandedButtonView = expandedButtonView;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:CYRKeyboardButtonDidShowExpandedInputNotification object:self];
            
            [self hideInputView];
        }
    } else if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateEnded) {
        if (self.panGestureRecognizer.state != UIGestureRecognizerStateRecognized) {
            [self handleTouchUpInside];
        }
    }
}

- (void)hideInputView
{
    self.highlighted = NO;
    [self.buttonView removeFromSuperview];
    self.buttonView = nil;
    
    [self setNeedsDisplay];
}

- (void)hideExpandedInputView
{
    if (self.expandedButtonView.type == CYRKeyboardButtonViewTypeExpanded) {
        [[NSNotificationCenter defaultCenter] postNotificationName:CYRKeyboardButtonDidHideExpandedInputNotification object:self];
    }
    
    [self.expandedButtonView removeFromSuperview];
    self.expandedButtonView = nil;
}

- (void)updateDisplayStyle
{
    switch (_style) {
        case CYRKeyboardButtonStylePhone:
            _keyCornerRadius = 4.f;
            break;
            
        case CYRKeyboardButtonStyleTablet:
            _keyCornerRadius = 6.f;
            break;
            
        default:
            break;
    }
    
    [self setNeedsDisplay];
}

#pragma mark - Internal - Text Handling

- (void)insertText:(NSString *)text
{
    BOOL shouldInsertText = YES;
    
    if ([self.textInput isKindOfClass:[UITextView class]]) {
        // Call UITextViewDelegate methods if necessary
        UITextView *textView = (UITextView *)self.textInput;
        NSRange selectedRange = textView.selectedRange;
        
        if ([textView.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
            shouldInsertText = [textView.delegate textView:textView shouldChangeTextInRange:selectedRange replacementText:text];
        }
    } else if ([self.textInput isKindOfClass:[UITextField class]]) {
        // Call UITextFieldDelgate methods if necessary
        UITextField *textField = (UITextField *)self.textInput;
        NSRange selectedRange = [self textInputSelectedRange];
        
        if ([textField.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            shouldInsertText = [textField.delegate textField:textField shouldChangeCharactersInRange:selectedRange replacementString:text];
        }
    }
    
    if (shouldInsertText == YES) {
        [self.textInput insertText:text];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:CYRKeyboardButtonPressedNotification object:self
                                                          userInfo:@{CYRKeyboardButtonKeyPressedKey : text}];
    }
}

- (NSRange)textInputSelectedRange
{
    UITextPosition *beginning = self.textInput.beginningOfDocument;
    
	UITextRange *selectedRange = self.textInput.selectedTextRange;
	UITextPosition *selectionStart = selectedRange.start;
	UITextPosition *selectionEnd = selectedRange.end;
    
	const NSInteger location = [self.textInput offsetFromPosition:beginning toPosition:selectionStart];
	const NSInteger length = [self.textInput offsetFromPosition:selectionStart toPosition:selectionEnd];
    
	return NSMakeRange(location, length);
}

#pragma mark - Internal - Configuration

- (void)updateButtonPosition
{
    // Determine the button sposition state based on the superview padding
    CGFloat leftPadding = CGRectGetMinX(self.frame);
    CGFloat rightPadding = CGRectGetMaxX(self.superview.frame) - CGRectGetMaxX(self.frame);
    CGFloat minimumClearance = CGRectGetWidth(self.frame) / 2 + 8;
    
    if (leftPadding >= minimumClearance && rightPadding >= minimumClearance) {
        self.position = CYRKeyboardButtonPositionInner;
    } else if (leftPadding > rightPadding) {
        self.position = CYRKeyboardButtonPositionLeft;
    } else {
        self.position = CYRKeyboardButtonPositionRight;
    }
}

- (void)setupInputOptionsConfiguration
{
    [self tearDownInputOptionsConfiguration];
    
    if (self.inputOptions.count > 0 || self.alternateInput != nil) {
        if (self.inputOptions.count > 0) {
            UILongPressGestureRecognizer *longPressGestureRecognizer =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showExpandedInputView:)];
            longPressGestureRecognizer.minimumPressDuration = _style == CYRKeyboardButtonStyleTablet ? 0.5 : 0.3;
            longPressGestureRecognizer.delegate = self;
            
            [self addGestureRecognizer:longPressGestureRecognizer];
            self.optionsViewRecognizer = longPressGestureRecognizer;
        }
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePanning:)];
        panGestureRecognizer.delegate = self;

        [self addGestureRecognizer:panGestureRecognizer];
        self.panGestureRecognizer = panGestureRecognizer;
    }
}

- (void)tearDownInputOptionsConfiguration
{
    [self removeGestureRecognizer:self.optionsViewRecognizer];
    [self removeGestureRecognizer:self.panGestureRecognizer];
}

#pragma mark - Touch Actions

- (void)handleInput:(NSString*)input {
    [self insertText:input];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    float delay = kMinimumInputViewShowingTime;
    
    if (now - self.lastTouchDown > delay) {
        delay = 0.f;
    }
    else {
        self.highlighted = YES;
    }
    
    [self performSelector:@selector(hideInputAndExpandedViews) withObject:nil afterDelay:delay];
}

- (void)handleTouchDown
{
    self.lastTouchDown = [[NSDate date] timeIntervalSince1970];
    [UIDevice.currentDevice playInputClick];
    [self showInputView];
}

- (void)handleTouchUpInside
{
    [self handleInput:self.input];
}

- (void)hideInputAndExpandedViews
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideInputAndExpandedViews) object:nil];
    
    [self hideInputView];
    [self hideExpandedInputView];
}

- (void)_handlePanning:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        if (self.expandedButtonView && self.expandedButtonView.selectedInputIndex != NSNotFound) {
            NSString *inputOption = self.inputOptions[self.expandedButtonView.selectedInputIndex];
            
            [self insertText:inputOption];
        }
        else if (self.alternateInput) {
            [self handleInput:_useAlternateInput ? self.alternateInput : self.input];
        }
        else if (!self.expandedButtonView.selectedInputIndex || self.expandedButtonView.selectedInputIndex == NSNotFound) {
            [self handleInput:self.input];
        }
        
        // Animate back the input labels back to their default states
        [UIView animateWithDuration:0.25f animations:^{
            self.alternateInputLabel.font = self.alternateFont;
            self.alternateInputLabel.alpha = self.alternateInputLabelAlpha;
            self.inputLabel.font = self.font;
            self.inputLabel.alpha = 1.f;
        }];
        
        [self hideExpandedInputView];
    } else {
        BOOL updateExpandedView = YES;
        
        if (self.alternateInput) {
            BOOL locationInOptions = CGRectContainsPoint(self.expandedButtonView.bounds, [recognizer locationInView:self.expandedButtonView]);
            _useAlternateInput = NO;
            
            // Default values
            CGPoint velocity = [recognizer velocityInView:self];
            UIFont* alternateInputFont = _alternateFont;
            UIFont* inputFont = _font;
            CGFloat alternateInputAlpha = _alternateInputLabelAlpha;
            CGFloat inputAlpha = 1.f;
            
            if (velocity.y > 0)
            {
                updateExpandedView = locationInOptions;
                
                if (!locationInOptions) {
                    alternateInputFont = [UIFont systemFontOfSize:MIN(_alternateInputLabel.font.pointSize + 1.5, _font.pointSize)];
                    inputFont = [UIFont systemFontOfSize:MAX(_inputLabel.font.pointSize - 1.5, 0)];
                    
                    alternateInputAlpha = alternateInputFont.pointSize / self.font.pointSize;
                    inputAlpha = inputFont.pointSize / self.font.pointSize;
                    
                    CGPoint location = [recognizer locationInView:self];
                    
                    if (location.y >= self.bounds.size.height) {
                        _useAlternateInput = YES;
                    }
                    [self setHighlighted:YES];
                }
            }
            else if (velocity.y < 0) {
                if (!locationInOptions) {
                    alternateInputFont = [UIFont systemFontOfSize:MAX(_alternateInputLabel.font.pointSize - 1.5, _alternateFont.pointSize)];
                    inputFont = [UIFont systemFontOfSize:MIN(_inputLabel.font.pointSize + 1.5, _font.pointSize)];
                    
                    alternateInputAlpha = alternateInputFont.pointSize / self.font.pointSize;
                    inputAlpha = inputFont.pointSize / self.font.pointSize;
                    [self setHighlighted:YES];
                }
            }
            
            // Animate the input labels for the vertical swipe
            [UIView animateWithDuration:0 animations:^{
                self.alternateInputLabel.font = alternateInputFont;
                self.alternateInputLabel.alpha = alternateInputAlpha;
                self.inputLabel.font = inputFont;
                self.inputLabel.alpha = inputAlpha;
            }];
        }
        
        if (updateExpandedView) {
            CGPoint location = [recognizer locationInView:self.superview];
            [self.expandedButtonView updateSelectedInputIndexForPoint:location];
        }
        else {
            [self hideExpandedInputView];
        }
    };
}

#pragma mark - Touch Handling

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    float delay = kMinimumInputViewShowingTime;
    
    if (now - self.lastTouchDown > delay) {
        delay = 0.f;
    }
    else {
        self.highlighted = YES;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hideInputView];
    });
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self hideInputView];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *color = self.keyColor;
    UIColor *bottomColor = self.keyBottomColor;
    
    if (_style == CYRKeyboardButtonStyleTablet && self.state == UIControlStateHighlighted) {
        color = self.keyHighlightedColor;
        bottomColor = self.keyBottomHighlightedColor;
    }
    
    UIColor *shadow = self.keyShadowColor;
    CGSize shadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat shadowBlurRadius = 0;
    
    UIBezierPath *roundedRectanglePath =
    [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height - 1) cornerRadius:self.keyCornerRadius];
    CGContextSaveGState(context);
    if (self.showShadow) {
        CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
    }
    if (!bottomColor) {
        [color setFill];
        [roundedRectanglePath fill];
    } else {
        [roundedRectanglePath addClip];
        
        CGColorSpaceRef baseSpace = CGColorSpaceCreateDeviceRGB();
        NSArray * colors = @[ (__bridge id)color.CGColor, (__bridge id)bottomColor.CGColor ];
        CGGradientRef gradient = CGGradientCreateWithColors(baseSpace, (__bridge CFArrayRef)colors, NULL);
        CGColorSpaceRelease(baseSpace), baseSpace = NULL;
        
        CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
        CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
        
        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
        CGGradientRelease(gradient), gradient = NULL;
    }
    
    CGContextRestoreGState(context);
}

@end
