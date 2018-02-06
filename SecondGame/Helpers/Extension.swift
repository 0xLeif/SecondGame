//
//  Extension.swift
//  SecondGame
//
//  Created by Zach Eriksen on 1/29/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import Foundation
import SceneKit

extension float2 {
	init(_ v: CGPoint) {
		self.init(Float(v.x), Float(v.y))
	}
}

extension SCNPhysicsContact {
	func match(_ category: Int, block: (_ matching: SCNNode, _ other: SCNNode) -> Void) {
		if nodeA.physicsBody!.categoryBitMask == category {
			block(nodeA, nodeB)
		}
		if nodeB.physicsBody?.categoryBitMask == category {
			block(nodeB, nodeA)
		}
	}
}
