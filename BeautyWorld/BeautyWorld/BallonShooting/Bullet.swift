//
//  Bullet.swift
//  BeautyWorld
//
//  Created by CGLab on 2017/6/26.
//  Copyright © 2017年 Apple. All rights reserved.
//

import UIKit
import SceneKit

class Bullet: SCNNode {
    override init () {
        super.init()
        let sphere = SCNSphere(radius: 0.025)
        self.geometry = sphere
        let shape = SCNPhysicsShape(geometry: sphere, options: nil)
        self.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        self.physicsBody?.isAffectedByGravity = false
        self.physicsBody?.categoryBitMask = CollisionCategory.bullets.rawValue
        self.physicsBody?.contactTestBitMask = CollisionCategory.balloon.rawValue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

