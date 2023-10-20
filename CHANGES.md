#CYRKeyboardButton Changelog

##0.5.x (TBD)
(Thanks @anovoselskyi)
* Added `keyBottomColor` and `keyBottomHighlightedColor` properties (default: nil) to allow an optional key background gradient.
* Added `borderWidth` (default: 0.0f) and `borderColor` (default: clear) for configurable border drawing.
* Added `showShadow` property (default: YES) to allow disabling shadow.
* Changed default `keyShadowColor` to black (alpha: 30%).
(Thanks @Edovia)
* Added `alternateInput` property (default: nil). This is the string that would be inserted upon a successful pan down gesture.
* Select the input in the options at the right index if found.
* Added `useNarrowerOptionWidth` property (default: NO)to draw narrower options.
* Added `trackingMarginInset` property (default: 0.0f) for inset to add to the tracking area.
* Added method (`-setInput:withText:`) to set different label text than input. This is helpful for instance on iPhone where the Space key shows “space” while the input is “ “.
* Added some delay (`kMinimumInputViewShowingTime`) for the input view to show; if a user tapped too fast the UI was not responsive enough.
* Added heightReduction properties in order for callout to fit in keyboard extension view.
* Fix minor display issues and warnings, including incorrect font in button view.

##0.5.3 (Monday, April 20th, 2015)
 * Added support for initialization via interface builder (Thanks @khaullen!)

##0.5.2 (Sunday, August 31st, 2014)
 * Adding notifications for when the expanded input view is shown or hidden.

##0.5.1 (Friday, August 1st, 2014)
 * Added support for UITextField (shouldChangeCharactersInRange:) and UITextView (shouldChangeTextInRange:) delegate methods.

##0.5.0 (Friday, August 1st, 2014)
 * Initial release
