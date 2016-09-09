// Copyright (c) 2016
// Author:  Mykhailo Vorontsov <michel06@ukr.net>

import UIKit

private struct Constants {
  struct Selectors {
    
    struct ForwardEvents {
      static let all:Selector = #selector(TextFieldWithPattern.forwardAllEvents(_:))
      static let allEditing:Selector = #selector(TextFieldWithPattern.forwardAllEditingEvents(_:))
      static let editingDidEndOnExit:Selector = #selector(TextFieldWithPattern.forwardEditingDidEndOnExit(_:))
      static let editingDidBegin:Selector = #selector(TextFieldWithPattern.forwardEditingDidBegin(_:))
      static let editingDidEnd:Selector = #selector(TextFieldWithPattern.forwardEditingDidEnd(_:))
    }
    
    static let textChanged:Selector = #selector(TextFieldWithPattern.textChanged(_:))
    static let fieldTapped:Selector = #selector(TextFieldWithPattern.tapped(_:))
  }
}

@objc class TextFieldWithPattern: UITextField {
  
  @IBOutlet weak var label: UILabel!
  @IBOutlet weak var textField: UITextField!
  
  /**
   Pattern to specifie text input, all 'non input' characters will be proceed to resulted text
   */
  @IBInspectable var pattern:String! = "__________" {
    didSet{
      invalidateUI()
    }
  }
  
  /**
   Public interface available in IB for entering input character.
   First symbol should be an input character
   */
  @IBInspectable var inputCharacterString:String! = "_"

  /**
   Color of characters marked from pattern
   */
  @IBInspectable var patternColor:UIColor = UIColor.grayColor()

  /**
   Input Character at pattern that should be replaced by Typed Text
   */
  var inputCharacter:Character! {
    get {
      return inputCharacterString.characters.first
    }
  }
  
  /**
   Calculate number of input characters in pattern,
   */
  var avilableCharacters:Int {
    get {
      var result = 0
      for char in pattern.characters {
        if char == inputCharacter {
          result += 1
        }
      }
      return result
    }
  }
  
  /**
   Typed text. No pattern involved (although pattern limits length of text to avilableCharacters)
   */
  override var text:String?  {
    get {
      return textField.text
    }
    set(newText) {
      textField.text = newText
      invalidateUI()
    }
  }
  
  override var placeholder:String? {
    get {
      return textField.placeholder
    }
    set (newPlacholder) {
      super.placeholder = newPlacholder
      textField?.placeholder = newPlacholder
    }
  }
  
  /**
   Full text with pattern applied.
   */
  var fullText:String? {
    get {
      return label.text
    }
  }
  
  //MARK: -Private
  @IBAction func tapped(sender: AnyObject) {
    textField.becomeFirstResponder()
  }

  //MARK: -Private

  func invalidateUI() {
    guard let newText = textField?.text else {
      return
    }
    
    if (newText.characters.count < 1 && placeholder?.characters.count > 0) {
      label.textColor = self.patternColor
      label.text = placeholder!
    } else {
      label.textColor = self.textColor ?? UIColor.blackColor()
      label.attributedText = self.applyPattern(pattern, inputString: newText)
    }
  }
  
  @IBAction func textChanged(sender: AnyObject) {
    invalidateUI()
    sendActionsForControlEvents(.EditingChanged)
  }
  
  func applyPattern(pattern: String, inputString:String?) -> NSAttributedString {

    let textAttributes = [ NSForegroundColorAttributeName : textField.textColor ?? UIColor.blackColor()]
    let patternAttribute = [ NSForegroundColorAttributeName : self.patternColor]
    
    // TODO: Pattern and symbol attributes should be different to prevent triming of terminating spaces
    let symbolAttribute = [ NSForegroundColorAttributeName : self.patternColor,
                            NSBackgroundColorAttributeName : UIColor.clearColor()
                            ]
    
    guard let inputString = inputString else {
      return NSAttributedString(string: pattern, attributes: patternAttribute)
    }
    
    var index = inputString.startIndex
    let result:NSMutableAttributedString = NSMutableAttributedString()
    
    for patternChar in pattern.characters {
      if patternChar == self.inputCharacter && index < inputString.endIndex  {
        let textChar:Character = inputString[index]
        
        result.appendAttributedString(NSAttributedString(string: String(textChar), attributes: textAttributes))

        index = index.advancedBy(1)
      } else {
        let attributes =  (patternChar == self.inputCharacter) ? patternAttribute : symbolAttribute
        result.appendAttributedString(NSAttributedString(string: String(patternChar), attributes: attributes))
      }
    }
    return result
  }
  
  
  override func becomeFirstResponder() -> Bool {
    return textField.becomeFirstResponder()
  }
  
  override func resignFirstResponder() -> Bool {
    return textField.resignFirstResponder()
  }
  
  override func drawRect(rect: CGRect) {
  // Draw nothing.
  }
  
  override func awakeFromNib() {
    
    if (nil == textField) {
      let frame = CGRectZero
      let newTextField = UITextField(frame: frame)
      newTextField.addTarget(self, action: Constants.Selectors.textChanged, forControlEvents: .EditingChanged)
      newTextField.delegate = self
      newTextField.keyboardType = self.keyboardType
      newTextField.autocapitalizationType = self.autocapitalizationType ?? .None
      newTextField.autocorrectionType = .No
      newTextField.spellCheckingType = .No
      
      newTextField.returnKeyType = returnKeyType
      newTextField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically

      let events = allControlEvents()
      if events.contains(UIControlEvents.AllEvents) {
        newTextField.addTarget(self, action: Constants.Selectors.ForwardEvents.all, forControlEvents: .AllEvents)
      }
      if events.contains(UIControlEvents.AllEditingEvents) {
        newTextField.addTarget(self, action: Constants.Selectors.ForwardEvents.allEditing, forControlEvents: .AllEditingEvents)
      }
      if events.contains(UIControlEvents.EditingDidEndOnExit) {
        newTextField.addTarget(self, action: Constants.Selectors.ForwardEvents.editingDidEndOnExit, forControlEvents: .EditingDidEndOnExit)
      }
      if events.contains(UIControlEvents.EditingDidBegin) {
        newTextField.addTarget(self, action: Constants.Selectors.ForwardEvents.editingDidBegin, forControlEvents: .EditingDidBegin)
      }
      if events.contains(UIControlEvents.EditingDidEnd) {
        newTextField.addTarget(self, action: Constants.Selectors.ForwardEvents.editingDidEnd, forControlEvents: .EditingDidEnd)
      }
      
      textField = newTextField
      self.addSubview(textField)
    }
    
    if (nil == label) {
      
      let newLabel = UILabel(frame: self.bounds)
      newLabel.textAlignment = .Center
      newLabel.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
      newLabel.textColor = self.textColor
      label = newLabel
      self.addSubview(label)
      label.adjustsFontSizeToFitWidth = true
      
      if (nil != font) {
        newLabel.font = self.font
      }
      
    }
    
    if (nil == gestureRecognizers?.last) {
      let tapGestureRecogniser = UITapGestureRecognizer(target: self, action: Constants.Selectors.fieldTapped)
      self.addGestureRecognizer(tapGestureRecogniser)
    }
    
    placeholder = super.placeholder
    text = super.text
    super.text = ""
    super.placeholder = ""
    
    invalidateUI()
  }
  
  override var font: UIFont? {
    didSet {
      label.font = font
    }
  }
  
}

// MARK: -Message forwarding
extension TextFieldWithPattern {
  @IBAction func forwardAllEvents(sender: AnyObject) {
    sendActionsForControlEvents(.AllEvents)
  }
  
  @IBAction func forwardAllEditingEvents(sender: AnyObject) {
    sendActionsForControlEvents(.AllEditingEvents)
  }
  
  @IBAction func forwardEditingDidEndOnExit(sender: AnyObject) {
    sendActionsForControlEvents(.EditingDidEndOnExit)
  }
  
  @IBAction func forwardEditingDidBegin(sender: AnyObject) {
    sendActionsForControlEvents(.EditingDidBegin)
  }
  
  @IBAction func forwardEditingDidEnd(sender: AnyObject) {
    sendActionsForControlEvents(.EditingDidEnd)
  }
}

// MARK: -UITextFieldDelegate
extension TextFieldWithPattern:UITextFieldDelegate {
  
  func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
    
    
    guard (range.location + range.length < avilableCharacters || string.characters.count < 1) else {
      return false
    }

    if (false == delegate?.textField?(self, shouldChangeCharactersInRange: range, replacementString: string)) {
      return false
    }
    
    return true
  }
  
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    guard  textField.text?.characters.count == avilableCharacters else {
      return false
    }
    
    if false == delegate?.textFieldShouldReturn?(self) {
      return false
    }
  
    return true

  }
  
  func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
    if false == delegate?.textFieldShouldBeginEditing?(self) {
      return false
    }
    return true
  }
  
  func textFieldDidBeginEditing(textField: UITextField) {
    delegate?.textFieldDidBeginEditing?(self)
  }

  func textFieldDidEndEditing(textField: UITextField) {
    delegate?.textFieldDidEndEditing?(self)
  }
  
  func textFieldShouldEndEditing(textField: UITextField) -> Bool {
    if false == delegate?.textFieldShouldEndEditing?(self) {
      return false
    }
    return true
  }

}
