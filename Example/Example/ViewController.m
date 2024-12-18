//
//  ViewController.m
//  Example
//
//  Created by Illya Busigin  on 7/19/14.
//  Copyright (c) 2014 Cyrillian, Inc. All rights reserved.
//

#import "ViewController.h"
#import "CYRKeyboardButton.h"
#import "NumberView.h"

@interface ViewController () <UITextViewDelegate>

@property (nonatomic, strong) NSMutableArray *keyboardButtons;
@property (nonatomic, strong) UIInputView *numberView;

@property (nonatomic, weak) IBOutlet UITextView *textView;

@end

@implementation ViewController

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Our keyboard keys
    NSArray *keys = @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"];
    NSArray *alts = @[@"[", @"]", @"{", @"}", @"_", @"^", @"<", @">", @"`", @"~"];
    self.keyboardButtons = [NSMutableArray arrayWithCapacity:keys.count];

    self.numberView = [[NumberView alloc] initWithFrame:CGRectZero inputViewStyle:UIInputViewStyleKeyboard];
    self.numberView.translatesAutoresizingMaskIntoConstraints = NO;
    self.numberView.allowsSelfSizing = YES;
    
    [keys enumerateObjectsUsingBlock:^(NSString *keyString, NSUInteger idx, BOOL *stop) {
        CYRKeyboardButton *keyboardButton = [CYRKeyboardButton new];
        keyboardButton.translatesAutoresizingMaskIntoConstraints = NO;
        keyboardButton.alternateInput = alts[idx];
        keyboardButton.input = keyString;
        keyboardButton.inputOptions = @[ keyString, @"A", @"B", @"C", @"D"];
        keyboardButton.keyInput = self.textView;
        if ( [keyString isEqualToString:@"0"] ) {
            keyboardButton.keyColor = UIColor.systemGray3Color;
            keyboardButton.keyBottomColor = UIColor.systemGrayColor;
            keyboardButton.keyTextColor = UIColor.whiteColor;
        }
        [self.numberView addSubview:keyboardButton];
        [self.keyboardButtons addObject:keyboardButton];
    }];
    
    if ( UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone ) {
        CYRKeyboardButton *keyboardButton = [CYRKeyboardButton new];
        keyboardButton.translatesAutoresizingMaskIntoConstraints = NO;
        keyboardButton.alternateInput = @"|";
        keyboardButton.input = @"\\";
        keyboardButton.keyInput = self.textView;
        [self.numberView addSubview:keyboardButton];
        [self.keyboardButtons addObject:keyboardButton];
    }

    [self updateConstraintsForInterfaceSize:self.view.frame.size];
    self.textView.inputAccessoryView = self.numberView;
    
    // Subscribe to keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [self updateConstraintsForInterfaceSize:size];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Constraint Management

- (void)updateConstraintsForInterfaceSize:(CGSize)size
{
    // Remove any existing constraints
    [self.numberView removeConstraints:self.numberView.constraints];
    
    // Create our constraints
    NSMutableDictionary *views = [NSMutableDictionary dictionary];
    NSMutableString *visualFormatConstants = [NSMutableString string];
    NSDictionary *metrics = nil;
    BOOL isPortrait = size.height >= size.width;
    
    // Setup our metrics based on idiom & orientation
    switch (UIDevice.currentDevice.userInterfaceIdiom) {
    case UIUserInterfaceIdiomPhone:
        if ( isPortrait ) {
            metrics = @{
                @"height" : @(45),
                @"margin" : @(3),
                @"spacing" : @(6)
            };
        } else {
            metrics = @{
                @"height" : @(38),
                @"margin" : @(3),
                @"spacing" : @(5)
            };
        }
        break;
    case UIUserInterfaceIdiomPad:
    default:
        if ( isPortrait ) {
            metrics = @{
                @"height" : @(64),
                @"margin" : @(6),
                @"spacing" : @(12)
            };
        } else {
            metrics = @{
                @"height" : @(82),
                @"margin" : @(7),
                @"spacing" : @(14)
            };
        }
        break;
    }
    
    // Build the visual format string
    [self.keyboardButtons enumerateObjectsUsingBlock:^(CYRKeyboardButton *button, NSUInteger idx, BOOL *stop) {
        NSString *viewName = [NSString stringWithFormat:@"keyboardButton%lu", (unsigned long)idx];
        [views setObject:button forKey:viewName];
        
        if (idx == 0) {
            [visualFormatConstants appendString:[NSString stringWithFormat:@"H:|-margin-[%@]", viewName]];
        } else if (idx < self.keyboardButtons.count - 1) {
            [visualFormatConstants appendString:[NSString stringWithFormat:@"-spacing-[%@]", viewName]];
        } else {
            [visualFormatConstants appendString:[NSString stringWithFormat:@"-spacing-[%@]-margin-|", viewName]];
        }
    }];
    
    // Apply horizontal constraints
    [self.numberView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:visualFormatConstants options:0 metrics:metrics views:views]];
    
    // Apply vertical constraints
    [views enumerateKeysAndObjectsUsingBlock:^(NSString *viewName, id obj, BOOL *stop) {
        NSString *format = [NSString stringWithFormat:@"V:|-6-[%@]|", viewName];
        [self.numberView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:format options:0 metrics:nil views:views]];
    }];
    
    // Add height constraint
    [self.numberView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[accessoryView(==height)]" options:0 metrics:metrics views:@{ @"accessoryView" : self.numberView }]];
 
    // Add width constraint
    [self.keyboardButtons enumerateObjectsUsingBlock:^(CYRKeyboardButton *button, NSUInteger idx, BOOL *stop) {
        if (idx > 0) {
            CYRKeyboardButton *previousButton = self.keyboardButtons[idx - 1];
            
            [self.numberView addConstraint:[NSLayoutConstraint constraintWithItem:button attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:previousButton attribute:NSLayoutAttributeWidth multiplier:1 constant:0]];
        }
    }];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:textView action:@selector(resignFirstResponder)];
    
    [self.navigationItem setRightBarButtonItem:doneButton animated:YES];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    [self.navigationItem setRightBarButtonItem:nil animated:YES];
}

#pragma mark - UIKeyboard

- (void)keyboardWillShow:(NSNotification *)notification
{
    if ([self.textView isFirstResponder]) {
        NSDictionary *info = [notification userInfo];
        CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
        CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        
        [UIView animateWithDuration:duration
                         animations:^{
                             self.textView.contentInset = UIEdgeInsetsMake(self.textView.contentInset.top, self.textView.contentInset.left, kbSize.height, 0);
                             self.textView.scrollIndicatorInsets = UIEdgeInsetsMake(self.textView.contentInset.top, self.textView.scrollIndicatorInsets.left, kbSize.height, 0);
                         }];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if ([self.textView isFirstResponder]) {
        NSDictionary *info = [notification userInfo];
        CGFloat duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
        
        [UIView animateWithDuration:duration
                         animations:^{
                             self.textView.contentInset = UIEdgeInsetsMake(self.textView.contentInset.top, self.textView.contentInset.left, 0, 0);
                             self.textView.scrollIndicatorInsets = UIEdgeInsetsMake(self.textView.contentInset.top, self.textView.scrollIndicatorInsets.left, 0, 0);
                         }];
    }
}

@end
