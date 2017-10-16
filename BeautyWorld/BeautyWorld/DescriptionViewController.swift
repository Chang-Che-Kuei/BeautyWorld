//
//  DescriptionViewController.swift
//  BeautyWorld
//
//  Created by CGLab on 2017/7/11.
//  Copyright © 2017年 Apple. All rights reserved.
//

import UIKit

class DescriptionViewController: UIViewController {

    @IBOutlet weak var Description: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Description.lineBreakMode = NSLineBreakMode.byWordWrapping
        Description.numberOfLines = 0
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
