//
//  ViewController.swift
//  ImagesToVideo
//
//  Created by Justin Winter on 9/10/15.
//  Copyright © 2015 wintercreative. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    
    let path = NSBundle.mainBundle().pathForResource("hasselblad-01", ofType: "jpg")!
    
    var photosArray = [String]()
    for _ in 0...500 {
      photosArray.append(path)
    }
    
    let tlb = TimeLapseBuilder(photoURLs: photosArray)
    tlb.build({ (progress) -> Void in
      
      }, success: { (url) -> Void in
        print("SUCCESS: \(url)")
      }) { (error) -> Void in
        print(error)
    }
    
  }

}

