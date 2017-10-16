


#import <SceneKit/SceneKit.h>

@interface Domino : SCNNode

- (instancetype)initAtPosition:(SCNVector3)position withMaterial:(SCNMaterial *)material;
- (void)changeMaterial;
- (void)remove;
+ (SCNMaterial *)currentMaterial;

@end
