// Copyright (c) 2016
// Author:  Mykhailo Vorontsov <michel06@ukr.net>
//
// Swift2.0 adoption based on LRTextField
// https://github.com/LR-Studio

import UIKit

private struct Constants {
  struct ValidationKeys {
    static let invalid = "invalid"
    static let valid = "valid"
    static let color = "VALIDATION_INDICATOR_COLOR"
  }
  
  struct LokalKeys {
    static let email = "E-Mail"
    static let invalidEmail = "Invalid E-Mail"
    
    static let password = "Password"
    static let phone = "Phone"
  }
  
  struct Selectors {
    static let editingBegin:Selector = #selector(FormattedTextField.textFieldEdittingDidBeginInternal(_:))
    static let editingChange:Selector = #selector(FormattedTextField.textFieldEdittingDidChangeInternal(_:))
    static let editingEnd:Selector = #selector(FormattedTextField.textFieldEdittingDidEndInternal(_:))
  }
  
  struct Colors {
    static let placeholder = UIColor.grayColor().colorWithAlphaComponent(0.7)
    static let hint = UIColor.grayColor().colorWithAlphaComponent(0.7)
    static let valid = UIColor(red: 35.0/255.0, green: 199.0/255.0, blue: 90.0/255.0, alpha: 1.0)
    static let invalid = UIColor(red: 225.0/255.0, green: 51.0/255.0, blue: 40.0/255.0, alpha: 1.0)
  }
  
  static let animationDuration = 0.3
  static let borderAnimationKeypath = "borderColor"
  
  static let emailRegexp = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}"
  static let regexpPredicateFormat = "SELF MATCHES %@"
  static let phoneFormat = "(###)###-####"
  static let floatingLabelScale:CGFloat = 0.62
}

@IBDesignable class FormattedTextField: UITextField {
  
  //  MARK: - Sub types
  enum Style:Int {
    case Email //Default placeholder: 'Email';   Default validation: email validation regular expression
    case Phone //Default placeholder: 'Phone';   Default format: '###-###-####'
    case Password //Default placeholder: 'Password; Default: secure text entry
    case None //Default style
  }
  
  /**
   Validation block to be applied to validate raw text synchronously or asynchronously.
   
   - parameters:
   - textField:
   - text: The raw text of the text field
   - returns: A dictionary with key of YES or NO and value of string to be displayed.
   */
  typealias ValidationBlock = (textField: FormattedTextField, text:String) -> NSDictionary
  
  //MARK: - Accessors
  
  @IBInspectable var validationFailedMessage:String? = nil
  
  func showErrorMessage(message:String?) {
    if let message = message {
      runValidationViewAnimation([Constants.ValidationKeys.invalid : message])
      errorState = true
      
    } else {
      if errorState {
        showBorderWithColor(UIColor.clearColor())
        hintLabel.text = hintText
        errorState = false
      }
    }
  }
  
  /**
   Regexp to validate
   */
  @IBInspectable var validationRegexp:String? = nil {
    didSet {
      guard let validationRegexp = validationRegexp else {
        internalValidationBlock = nil
        return
      }
      let emailRegexp = validationRegexp
      
      internalValidationBlock = {[weak self](textField, text) -> NSDictionary in
        let errorMessage = self?.validationFailedMessage ?? ""
        let emailTest = NSPredicate(format: Constants.regexpPredicateFormat, emailRegexp)
        let evaluationResult = emailTest.evaluateWithObject(text)
        if true == evaluationResult {
          return NSDictionary()
        } else {
          return [Constants.ValidationKeys.invalid : errorMessage]
        }
      }
      
    }
  }
  
  /**
   Internal block that allows to validate textfield
   */
  var validationBlock:((text:String?, rawText:String?) -> Bool)? = nil {
    didSet {
      validationRegexp = nil
      guard let validationBlock = validationBlock else {
        return
      }
      internalValidationBlock = {[weak self](textField, text) -> NSDictionary in
        let errorMessage = self?.validationFailedMessage ?? ""
        if true == validationBlock(text: self?.text, rawText: self?.rawText) {
          return NSDictionary()
        } else {
          return [Constants.ValidationKeys.invalid : errorMessage]
        }
      }
      
    }
  }
  
  var errorState:Bool = false
  
  /**
   Return either input is valid
   */
  var valid:Bool {
    get {
      
      guard let validationBlock = internalValidationBlock else {return true}
      let validationInfo = validationBlock(textField: self, text: rawText)
      let isValid = (nil == validationInfo[Constants.ValidationKeys.invalid])
      return isValid
    }
  }
  
  /**
   String contained inputCharacter for pattern to make it accessible via IB
   
   Default is #
   */
  @IBInspectable var inputCharacterString:String! = "#"
  
  /**
   Input character that in the format pattern that should be replaced by user input.
   As in XCode current version IB doesn't support @IBInspectable Characters,
   character taken from inputCharacterString exposed to IB
   
   Default is #
   */
  var inputSymbol:Character {
    get {
      return inputCharacterString?.characters.first ?? "#"
    }
  }
  
  /**
   Mask of input text. InputSymbol will be changed by user input.
   
   '#' represent any single character input by default.
   
   If nil, text field should not be formatted, but can be verified by regexp
   
   Default is nil.
   */
  @IBInspectable var format:String? = nil {
    willSet {
      tempVariable = rawText
      print("\(tempVariable)")
    }
    didSet {
      guard let tempVariable = tempVariable where tempVariable.characters.count > 0 else {
        return
      }
      renderString(tempVariable)
      autoFillFormat()
    }
  }
  
  /**
   Read-only. Return text without mask.
   */
  var rawText:String {
    get {
      guard let text = text where text.characters.count > 0 else {
        return ""
      }
      
      guard let format = format where format.characters.count > 0 else {
        return text ?? ""
      }
      
      return unformatText(text, format: format)
    }
  }
  
  func unformatText(text:String, format:String, formatOffset:Int = 0) -> String {
    var index = 0
    return unformatText(text, format:format, startFrom:&index, formatOffset:formatOffset)
  }
  
  /**
   Clear text from formatting, counting cursor position and how text changed
   */
  func unformatText(text:String, format:String, inout startFrom:Int, formatOffset:Int = 0) -> String {
    
    guard text.characters.count > 0  else {
      return ""
    }
    
    guard format.characters.count > 0 else {
      return text
    }
    
    guard format.characters.count >= text.characters.count else {
      assert(false, "textfield format shorter then text")
      return ""
    }
    
    var string = text
    var index = string.endIndex.predecessor()
    
    let startIndex = string.startIndex
    let endIndex = string.endIndex
    let formatStart = format.startIndex
    
    while index > startIndex {
      var distance = startIndex.distanceTo(index)
      if (distance >= startFrom) {
        distance -= formatOffset
      } else {
        break
      }
      distance = max(distance, 0)
      distance = min(distance, startIndex.distanceTo(endIndex))
      
      let formatIndex = formatStart.advancedBy(distance)
      let formatChar = format[formatIndex]
      let textChar = string[index]
      if formatChar != inputSymbol && textChar == formatChar {
        string.removeAtIndex(index)
        if distance < startFrom {
          startFrom -= 1
        }
      }
      index = index.predecessor()
    }
    return string
    
  }
  
  /**
   Indicate whether the floating label animation is enabled.
   
   Default is true.
   */
  @IBInspectable var enableAnimation:Bool = true {
    didSet {
      updatePlaceholder()
      updateHint()
    }
  }
  
  
  /**
   Text to be displayed in the floating hint label.
   
   Default is empty string.
   */
  @IBInspectable var hintText:String = "" {
    didSet {
      updateHint()
    }
  }
  
  /**
   Text colour to be applied to the floating hint text.
   
   Default is [UIColor grayColor].
   */
  @IBInspectable var hintTextColor:UIColor = UIColor.grayColor() {
    didSet {
      updateHint()
    }
  }
  
  /**
   Style of text: email, phone, password
   
   Default is .None.
   */
  var style:Style = .None {
    didSet {
      updateStyle()
    }
  }
  
  var placeholderBelow = false
  var hintBelow = true
  
  func setAHintBelow(hadHintBelow:Bool) {
    layer.cornerRadius = 5.0
  }
  
  func aHintBelow() -> Bool {
    return hintBelow
  }
  
  /**
   Init with float label height and pre-defined style
   
   - parameters:
   - frame: frame of new component
   - labelHeight: height of a hint and placeholder labels
   - style: textfield style, default = .None
   
   - returns: FormattedTextField
   */
  init(frame: CGRect, labelHeight:CGFloat, style:Style = .None) {
    super.init(frame: frame)
    self.style = style
    self.floatingLabelHeight = labelHeight
    self.updateUI()
  }
  
  override convenience init(frame: CGRect) {
    let height = frame.size.height / 2.0
    self.init(frame:frame, labelHeight: height)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
//    if let floatingLabelScale = floatingLabelScale {
//      floatingLabelHeight = frame.size.height * floatingLabelScale
//    } else {
//      floatingLabelHeight = frame.size.height * 0.62
    let fontHeight = font?.lineHeight ?? 1.0
    floatingLabelHeight = fontHeight * Constants.floatingLabelScale
//    }
    
    updateUI()
    placeholderText = placeholder ?? "";
    super.placeholder = nil
  }
  
  //  MARK: - Private variables
  
  private var placeholderLabel:UILabel! = nil
  private var hintLabel:UILabel! = nil
  private var placeholderXInset:CGFloat = 0
  private var placeholderYInset:CGFloat = 1
  
  private var hintXInset:CGFloat = 0
  private var hintYInset:CGFloat = -1
  
  // Internal block that returns dictionary with error description, if validation failed.
  private var internalValidationBlock: ValidationBlock! = nil
  
  private var prevTextString: String? = nil
  private var placeholderText: String = ""
  
  // Dynamic accessors using extension required to make them, avaialbble using Appearance
  private var _placeholderActiveColor:UIColor = UIColor.clearColor()
  private var _placeholderInactiveColor:UIColor = UIColor.grayColor().colorWithAlphaComponent(0.7)
  private var _floatingLabelHeight:CGFloat! = nil
  private var _validationYesColor:UIColor = UIColor.greenColor()
  private var _validationNoColor:UIColor = UIColor.redColor()
  
  convenience init() {
    self.init(frame:CGRectZero)
  }
  
  /**
   Private variable to store temporary raw value during changing of filter
   */
  private var tempVariable:String?
  
}

// MARK: - Overrides
extension FormattedTextField {
  override var text:String? {
    set(newText) {
      let animationEnabled = enableAnimation
      enableAnimation = false
      let rawText = unformatText(newText ?? "", format: format ?? "")
      renderString(rawText ?? "")
      autoFillFormat()
      enableAnimation = animationEnabled
    }
    get {
      return super.text
    }
  }
  
  override var borderStyle:UITextBorderStyle {
    didSet {
      initLayer()
    }
  }
  
///  Can't use overloaded apperance methods becaue of swift->obj-c issues
  var borderStyleAppearance:UITextBorderStyle {
    set {
      self.borderStyle = newValue
    }
    get {
      return self.borderStyle
    }
  }
  
  override var placeholder:String? {
    didSet {
      placeholderText = placeholder ?? ""
      updatePlaceholder()
      super.placeholder = nil
    }
  }
  
}

// MARK: - Update Method
extension FormattedTextField {
  
  private func updateUI() {
    propertyInit()
    placeholderLabel = UILabel()
    placeholderLabel.backgroundColor = UIColor.clearColor()
    placeholderLabel.font = font
    placeholderLabel.adjustsFontSizeToFitWidth = true
    
    hintLabel = UILabel()
    hintLabel.backgroundColor = UIColor.clearColor()
    hintLabel.font = font
    hintLabel.adjustsFontSizeToFitWidth = true
    
    updateHint()
    updatePlaceholder()
    
    addSubview(placeholderLabel)
    addSubview(hintLabel)
    
    addTarget(self, action: Constants.Selectors.editingBegin, forControlEvents: .EditingDidBegin)
    addTarget(self, action: Constants.Selectors.editingChange, forControlEvents: .EditingChanged)
    addTarget(self, action: Constants.Selectors.editingEnd, forControlEvents: .EditingDidEnd)
    
    updateStyle()
  }
  
  private func propertyInit() {
    placeholderXInset = 0
    placeholderYInset = 1
    hintXInset = 0
    hintYInset = 1
    
    enableAnimation = false
    _placeholderInactiveColor = Constants.Colors.placeholder
    _placeholderActiveColor = self.tintColor
    hintText = ""
    hintTextColor = Constants.Colors.hint
    prevTextString = ""
    internalValidationBlock = nil
    clipsToBounds = false
    
    validationYesColor = Constants.Colors.valid
    validationNoColor = Constants.Colors.invalid
    
    initLayer()
  }
  
  private func updatePlaceholder() {
    guard nil != placeholderLabel else {
      return
    }
    placeholderLabel.text = placeholderText
    
    //Label shown over the textfield
    if true == editing || text?.characters.count > 0 || false == enableAnimation {
      let scale = Constants.floatingLabelScale
      placeholderLabel.transform = CGAffineTransformMakeScale(scale, scale)
      placeholderLabel.frame = placeholderLabelFrame()
    } else {
      //Label shown the same as placeholder
      self.placeholderLabel.transform = CGAffineTransformIdentity
      placeholderLabel.frame = super.textRectForBounds(bounds)
    }
    placeholderLabel.textColor = editing ? _placeholderActiveColor : _placeholderInactiveColor
    
  }
  
  private func updateHint() {
    
    guard nil != hintLabel else {
      return
    }
    
    hintLabel.text = hintText
    hintLabel.textColor = hintTextColor
    let fontHeight = font?.lineHeight ?? 1.0
    let scale = Constants.floatingLabelScale
    hintLabel.transform = CGAffineTransformMakeScale(scale, scale)
    hintLabel.frame = hintLabelFrame()
    hintLabel.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    hintLabel.textAlignment = .Left
    hintLabel.alpha = 1.0
  }
  
  private func updateStyle() {
    switch style {
    case .Email:
      placeholder = Constants.LokalKeys.email.localized()
      format = nil
      validationFailedMessage =  Constants.LokalKeys.invalidEmail.localized()
      validationRegexp = Constants.emailRegexp
      
    case .Phone:
      placeholder = Constants.LokalKeys.phone.localized()
      keyboardType = .PhonePad
      format = Constants.phoneFormat
    case .Password:
      placeholder = Constants.LokalKeys.password.localized()
      secureTextEntry = true
    default: break
    }
  }
}
//  MARK: - Target Method
extension FormattedTextField {
  
  @IBAction func textFieldEdittingDidBeginInternal(sender:UITextField) {
    showBorderWithColor(UIColor.clearColor())
    runDidBeginAnimation()
  }
  
  @IBAction func textFieldEdittingDidEndInternal(sender:UITextField) {
    autoFillFormat()
    runDidEndAnimation()
  }
  
  @IBAction func textFieldEdittingDidChangeInternal(sender:UITextField) {
    runDidChange()
    if errorState {
      showErrorMessage(nil)
    }
  }
}

//  MARK: - Private Method
extension FormattedTextField {
  private func sanitizeStrings() {
    var currentText = text ?? ""
    let currentFormat = format ?? ""
    if (currentText.characters.count > currentFormat.characters.count) {
      currentText = currentText.substringToIndex(currentText.startIndex.advancedBy(currentFormat.characters.count))
    }
    renderString(currentText)
  }
  
  private func renderString(raw:String) {
    
    guard let format = format else {
      super.text = raw
      return
    }
    
    let selRange = selectedTextRange;
    let selStartPos = selRange?.start;
    var cursorOffset:Int = (nil != selStartPos) ? offsetFromPosition(beginningOfDocument, toPosition: selStartPos!) : 0
    
    var charactersChanged = raw.characters.count - (prevTextString ?? "").characters.count
    
    // If string is fully filled then character replaced, so at least on character affected
    if 0 == charactersChanged && raw.characters.count == format.characters.count {
      charactersChanged = 1
    }
    
    // Remove formatting after cursor position
    let string = unformatText(raw, format: format, startFrom: &cursorOffset, formatOffset: charactersChanged)
    
    var result = ""
    var index = format.startIndex
    var last = string.startIndex
    
    while index < format.endIndex {
      guard last < string.endIndex else {
        break
      }
      let charAtMask = format[index]
      let charAtCurrent = string[last]
      var shouldIncrementLast = true
      
      if (charAtMask == inputSymbol) {
        result.append(charAtCurrent)
      } else {
        result.append(charAtMask)
        if charAtMask != charAtCurrent {
          shouldIncrementLast = false
          let currentDistance = format.startIndex.distanceTo(index)
          if currentDistance < cursorOffset {
            cursorOffset += 1
          }
        }
      }
      if true == shouldIncrementLast {
        last = last.successor()
      }
      index = index.successor()
    }
    super.text = result
    
    let cursorPosition = positionFromPosition(beginningOfDocument, offset: cursorOffset) ?? endOfDocument
    selectedTextRange = textRangeFromPosition(cursorPosition, toPosition: cursorPosition)
    
    prevTextString = text
  }
  
  private func autoFillFormat() {
    var result = text ?? ""
    guard let format = format where format.characters.count > result.characters.count  else {
      return
    }
    
    for index in format.startIndex.successor() ..< format.endIndex {
      let charAtMask = format[index]
      guard charAtMask != inputSymbol else {
        return
      }
      result.append(charAtMask)
    }
    super.text = result
    prevTextString = text
  }
  
  private func runDidBeginAnimation() {
    let textString = text ?? ""
    
    if textString.characters.count > 0 || false == enableAnimation {
      let showPlaceholderBlock:(() -> Void)? = { () -> Void in
        self.placeholderLabel.textColor = self._placeholderActiveColor
      }
      
      let showHintBlock = { () -> Void in
        self.hintLabel.text = self.hintText
        self.hintLabel.textColor = self.hintTextColor
        self.hintLabel.alpha = 1.0
      }
      
      UIView.transitionWithView(placeholderLabel,
                                duration: Constants.animationDuration,
                                options: [.BeginFromCurrentState, .TransitionCrossDissolve],
                                animations: showPlaceholderBlock,
                                completion: nil);
      
      UIView.transitionWithView(placeholderLabel,
                                duration: Constants.animationDuration,
                                options: .BeginFromCurrentState,
                                animations: showHintBlock,
                                completion: nil);
      
    } else {
      
      let showBlock = { () -> Void in
        self.updatePlaceholder()
        self.hintLabel.text = self.hintText
        self.hintLabel.alpha = 1.0
      }
      UIView.animateWithDuration(Constants.animationDuration, animations: showBlock)
    }
  }
  
  private func runDidEndAnimation() {
    let textString = text ?? ""
    
    // Change to >= 0 if empty fields validation needed.
    if textString.characters.count > 0 || false == enableAnimation {
      if nil != internalValidationBlock {
        validateText()
      }
      let hideBlock = { () -> Void in
        self.placeholderLabel.textColor = self._placeholderInactiveColor
        self.hintLabel.alpha = 0.0
      }
      
      UIView.transitionWithView(placeholderLabel,
                                duration: Constants.animationDuration,
                                options: .BeginFromCurrentState,
                                animations: hideBlock,
                                completion: nil);
      
    } else {
      let hideBlock = { () -> Void in
        self.updatePlaceholder()
        self.updateHint()
      }
      UIView.animateWithDuration(Constants.animationDuration, animations: hideBlock)
    }
  }
  
  private func runDidChange() {
    guard nil != format else {
      return
    }
    sanitizeStrings()
  }
}

//  MARK: - Validation
extension FormattedTextField {
  
  private func validateText() {
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
    
    indicator.startAnimating()
    let rightOverlay = rightView
    let overlayMode = rightViewMode
    rightView = indicator
    rightViewMode = .Always
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { [weak self] () -> Void in
      guard let strongSelf = self else {
        return
      }
      let validationInfo = strongSelf.internalValidationBlock(textField: strongSelf, text: strongSelf.rawText)
      if let color = validationInfo[Constants.ValidationKeys.color] as? UIColor {
        strongSelf.validationYesColor = color
      }
      if let color = validationInfo[Constants.ValidationKeys.color] as? UIColor {
        strongSelf.validationNoColor = color
      }
      dispatch_async(dispatch_get_main_queue()) {[weak self] () -> Void in
        guard let strongSelf = self else {
          return
        }
        strongSelf.rightView = nil
        strongSelf.rightView = rightOverlay
        strongSelf.rightViewMode = overlayMode
        strongSelf.runValidationViewAnimation(validationInfo)
      }
    }
  }
  
  private func runValidationViewAnimation(validationInfo:NSDictionary) {
    
    let animationBlock = { () -> Void in
      self.layoutValidationView(validationInfo);
    }
    
    if nil != validationInfo[Constants.ValidationKeys.valid] {
      showBorderWithColor(validationYesColor)
    } else if nil != validationInfo[Constants.ValidationKeys.invalid] {
      showBorderWithColor(validationNoColor)
    }
    
    UIView.transitionWithView(placeholderLabel,
                              duration: Constants.animationDuration,
                              options: .BeginFromCurrentState,
                              animations: animationBlock,
                              completion: nil);
  }
  
  private func layoutValidationView(validationInfo:NSDictionary) {
    if let text = validationInfo[Constants.ValidationKeys.valid] as? String {
      hintLabel.text = text
      hintLabel.textColor = validationYesColor
      hintLabel.alpha = 1.0
    } else if let text = validationInfo[Constants.ValidationKeys.invalid] as? String {
      hintLabel.text = text
      hintLabel.textColor = validationNoColor
      hintLabel.alpha = 1.0
    }
  }
  
  private func initLayer() {
    switch borderStyle {
    case .RoundedRect:
      layer.borderWidth = 1.0
      layer.cornerRadius = 6.0
      layer.borderColor = UIColor.clearColor().CGColor
      
    case .Line:
      layer.borderWidth = 1.0
      layer.cornerRadius = 0.0
      layer.borderColor = UIColor.clearColor().CGColor
    case .Bezel:
      layer.borderWidth = 2.0
      layer.cornerRadius = 0.0
      layer.borderColor = UIColor.clearColor().CGColor
    case .None:
      layer.cornerRadius = 0.0
      layer.borderWidth = 0.0
    }
  }
  
  private func showBorderWithColor(color:UIColor) {
    let showColorAnimation = CABasicAnimation(keyPath: Constants.borderAnimationKeypath)
    showColorAnimation.fromValue = layer.borderColor
    showColorAnimation.toValue = color.CGColor
    showColorAnimation.duration = Constants.animationDuration
    layer.addAnimation(showColorAnimation, forKey: Constants.borderAnimationKeypath)
    layer.borderColor = color.CGColor
  }
  
  private func placeholderLabelFrame() -> CGRect {
    let yOffset = (false == placeholderBelow) ? -placeholderYInset - floatingLabelHeight : self.bounds.size.height + placeholderYInset
    
    let frame = CGRectMake(placeholderXInset,
                           yOffset,
                           bounds.size.width - 2.0 * placeholderXInset,
                           floatingLabelHeight)
    
    return frame
  }
  
  private func hintLabelFrame() -> CGRect {
    let yOffset = (false == hintBelow) ? -hintYInset - floatingLabelHeight : self.bounds.size.height + hintYInset
    
    let frame = CGRectMake(hintXInset,
                           yOffset,
                           bounds.size.width - 2.0 * hintXInset,
                           floatingLabelHeight)
    
    return frame
  }
  
}

// MARK: -Appearance proptocol custom accessors
// Instant variable can't be used because of Swift2.2 limitation. Additional category with dynamic accessors needed.
extension FormattedTextField {
  
  /// Show hint below if true or above if false (false by default)
  var showHintBelow:Bool {
    set {
      if hintBelow != newValue {
        hintBelow = newValue
        self.updateHint()
      }
    }
    get {
      return hintBelow
    }
  }
  
  /// Show placeholder below if true or above if false (false by default)
  var showPlaceholderBelow:Bool {
    set {
      if placeholderBelow != newValue {
        placeholderBelow = newValue
        self.updatePlaceholder()
      }
    }
    get {
      return placeholderBelow
    }
  }
  
  /**
   Text color to be applied to floating placeholder text when editing.
   Default is tint color.
   */
  @IBInspectable var placeholderActiveColor:UIColor {
    set {
      if newValue != _placeholderActiveColor {
        _placeholderActiveColor = newValue
        updatePlaceholder()
      }
    }
    get {
      return _placeholderActiveColor
    }
  }
  
  /**
   Text color to be applied to floating placeholder text when not editing.
   Default is 70% gray.
   */
  @IBInspectable var placeholderInactiveColor:UIColor {
    set {
      if newValue != _placeholderInactiveColor {
        _placeholderInactiveColor = newValue
        updatePlaceholder()
      }
    }
    get {
      return _placeholderActiveColor
    }
  }
  
  /**
   Height of floating Label.
   Default is 0.5 * self.frame.height
   */
  @IBInspectable var floatingLabelHeight:CGFloat! {
    set {
      if newValue != _floatingLabelHeight {
        _floatingLabelHeight = newValue
        updatePlaceholder()
        updateHint()
      }
    }
    get {
      return _floatingLabelHeight
    }
  }
  
  /// Color for hint if correct validation block
  var validationYesColor:UIColor {
    set {
      _validationYesColor = newValue
    }
    get {
      return _validationYesColor
    }
  }
  
  /// Color for hint if validation block invalid
  var validationNoColor:UIColor {
    set {
      _validationNoColor = newValue
    }
    get {
      return _validationNoColor
    }
  }
  
  /// Allow setup hint font
  var hintFont:UIFont? {
    set {
      hintLabel.font = newValue
    }
    get {
      return hintLabel.font
    }
  }
  
  /// Allow setup placeholder font
  var placeholderFont:UIFont? {
    set {
      placeholderLabel.font = newValue
    }
    get {
      return placeholderLabel.font
    }
  }
  
}
