//
//  Pyramid.m
//  arkit-by-example
//
//  Created by md on 6/15/17.
//  Copyright © 2017 ruanestudios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Pyramid.h"
#import "CollisionCategory.h"
#import "PBRMaterial.h"

static int currentMaterialIndex = 0;

@implementation Pyramid

- (instancetype)initAtPosition:(SCNVector3)position withMaterial:(SCNMaterial *)material {
  self = [super init];
  
  float dimension = 0.2;
    SCNPyramid *pyramid = [SCNPyramid pyramidWithWidth:dimension height:dimension length:dimension];
  pyramid.materials = @[material];
  SCNNode *node = [SCNNode nodeWithGeometry:pyramid];

  // The physicsBody tells SceneKit this geometry should be manipulated by the physics engine
    
  node.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeDynamic shape:nil];
  node.physicsBody.mass = 2.0;
  node.physicsBody.categoryBitMask = CollisionCategoryPyramid;
  node.position = position;
    
  [self addChildNode:node];
  return self;
}

- (void)changeMaterial {
  // Static, all future pyramids use this to have the same material
  currentMaterialIndex = (currentMaterialIndex + 1) % 4;
  [self.childNodes firstObject].geometry.materials = @[[Pyramid currentMaterial]];
}

+ (SCNMaterial *)currentMaterial {
  NSString *materialName;
    NSLog(@"index=%d",currentMaterialIndex);
  switch(currentMaterialIndex) {
    case 0:
      materialName = @"rustediron-streaks";
      break;
    case 1:
      materialName = @"carvedlimestoneground";
      break;
    case 2:
      materialName = @"granitesmooth";
      break;
    case 3:
      materialName = @"old-textured-fabric";
      break;
  }
  return [[PBRMaterial materialNamed:materialName] copy];
}

@end
