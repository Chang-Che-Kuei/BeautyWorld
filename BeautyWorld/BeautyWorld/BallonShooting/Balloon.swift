//
//  Balloon.swift
//  BeautyWorld
//
//  Created by CGLab on 2017/6/26.
//  Copyright © 2017年 Apple. All rights reserved.
//

import UIKit
import SceneKit

class Balloon: SCNNode {
    override init() {
        super.init()
        let box = SCNCapsule(capRadius: 0.03, height: 0.1)
        box.firstMaterial?.diffuse.contents = UIColor.red
        self.geometry = box
        let shape = SCNPhysicsShape(geometry: box, options: nil)
        self.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        self.physicsBody?.isAffectedByGravity = false
        self.physicsBody?.categoryBitMask = CollisionCategory.balloon.rawValue // See below for what CollisionCategory is!
        self.physicsBody?.contactTestBitMask = CollisionCategory.bullets.rawValue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}



