// Copyright (c) 2016
// Author:  Mykhailo Vorontsov <michel06@ukr.net>


import UIKit

class DatePickerInputView: UIView {

  @IBOutlet weak var toolBar: UIToolbar!
  @IBOutlet weak var datePicker: UIDatePicker!
  @IBOutlet weak var doneButton: UIBarButtonItem!
  
  weak var textField:UITextField?

  lazy var formatter:NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.timeStyle = .NoStyle
    formatter.dateStyle = .MediumStyle
    return formatter
  }()
  
  static func instantiateWithTextField(aTextField:UITextField) -> DatePickerInputView {
    let nib = UINib.init(nibName: "DatePickerInputView", bundle: nil)
    let topObjects = nib.instantiateWithOwner(nil, options: nil)
    let inputView = topObjects.first as! DatePickerInputView
    inputView.textField = aTextField
    aTextField.inputView = inputView
    return inputView
  }
  
  @IBAction func dateChanged(sender: UIDatePicker) {
    textField?.text = formatter.stringFromDate(sender.date)
    textField?.sendActionsForControlEvents(.ValueChanged)
  }
  
  @IBAction func doneTouched(sender: AnyObject) {
    textField?.sendActionsForControlEvents(.EditingDidEndOnExit)
  }

}
