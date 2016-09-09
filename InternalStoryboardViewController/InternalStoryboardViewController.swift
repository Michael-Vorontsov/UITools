// Copyright (c) 2016
// Author:  Mykhailo Vorontsov <michel06@ukr.net>

import UIKit

class InternalStoryboardViewController: UIViewController {
  
  /**
   Specify name of storyboard that should be loaded.
   */
  @IBInspectable var storyboardName:String = ""
  /**
   Specify identifier of controller in storyboard that should be loaded. If nil - initial controller will be loaded.
   */
  @IBInspectable var controllerIdentifier:String?
  
  /**
   Provide access to embedded controller for customisation (during segues for example)
   */
  lazy var embeddedController:UIViewController! = {
    let storyboard = UIStoryboard(name: self.storyboardName, bundle: nil)
    guard let controller:UIViewController = (nil == self.controllerIdentifier) ?  storyboard.instantiateInitialViewController() :
      storyboard.instantiateViewControllerWithIdentifier(self.controllerIdentifier!) else {
        assert(false, "No controller available!")
        return nil
    }
    return controller
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let controller = embeddedController else {
      return
    }
    addChildViewController(controller)
    controller.view.frame = view.bounds
    controller.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
    view.addSubview(controller.view)
  }
  
}
