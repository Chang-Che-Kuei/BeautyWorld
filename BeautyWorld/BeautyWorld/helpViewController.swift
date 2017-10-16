//
//  helpViewController.swift
//  BeautyWorld
//
//  Created by CGLab on 2017/7/11.
//  Copyright © 2017年 Apple. All rights reserved.
//

import UIKit

var FirstTimeToHelp = true
class helpViewController: UIViewController,UIPickerViewDelegate, UIPickerViewDataSource {
    
    @IBOutlet weak var goToMainBtn: UIButton!
    @IBAction func PopupOut(_ sender: Any) {
        
    }
    @IBOutlet weak var descriptionImage: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var itemPicker: UIPickerView!
    
    let items = ["家具類","3D模型","氣球射擊","音樂海草","崩潰金字塔","骨牌"]
    let descriptions = ["擺放逼真的家具，可以透過手勢旋轉、縮放和移動",
                        "將酷炫的3D模型隨心所欲放置在平面上",
                        "氣球就快要溜走了～快用大炮射下它！",
                        "種下一顆隨著音樂欣欣向榮的小樹吧！",
                        "點擊平面就會出現金字塔，無窮無盡的金字塔令人崩潰呢",
                        "點擊平面就會出現骨牌，長按了話就能推倒骨牌喔"]
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return items.count
    }
    
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int, forComponent component: Int)
        -> String? {
            // 設置第一列時
            if component == 0 {
                // 設置為陣列 week 的第 row 項資料
                return items[row]
            }
            print("component!=0")
            return "error"
    }
    
    // UIPickerView 改變選擇後執行的動作
    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int, inComponent component: Int) {
        if component == 0 {
            descriptionLabel.text = descriptions[row]
            descriptionImage.image = UIImage(named: "page3-\(row)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        itemPicker.delegate = self
        itemPicker.dataSource = self
        
        descriptionLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        descriptionLabel.numberOfLines = 0
        
        if FirstTimeToHelp{
            FirstTimeToHelp = false
        }
        else{
            goToMainBtn.isHidden = true
        }
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
