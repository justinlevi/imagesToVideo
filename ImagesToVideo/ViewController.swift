//
//  ViewController.swift
//  ImagesToVideo
//
//  Created by Justin Winter on 9/10/15.
//  Copyright © 2015 wintercreative. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

  @IBOutlet weak var progressView: UIProgressView!
  @IBOutlet weak var progressLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let path = NSBundle.mainBundle().pathForResource("hasselblad-01", ofType: "jpg")!
    
    var photosArray = [String]()
    for _ in 0...5000 {
      photosArray.append(path)
    }
    
    let tlb = TimeLapseBuilder(photoURLs: photosArray)
    tlb.build({ (progress) -> Void in
      
      dispatch_async(dispatch_get_main_queue()){
        self.progressLabel.text = "rendering \(progress.completedUnitCount) of \(progress.totalUnitCount) frames"
        self.progressView.setProgress(Float(progress.fractionCompleted), animated: true)
      }
      
      }, success: { (url) -> Void in
        print("SUCCESS: \(url)")
      }) { (error) -> Void in
        print(error)
    }
    
  }

}

