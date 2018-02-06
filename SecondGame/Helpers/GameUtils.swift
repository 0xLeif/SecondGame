//
//  GameUtils.swift
//  SecondGame
//
//  Created by Zach Eriksen on 2/5/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import Foundation
import SceneKit

extension SCNVector3 {
	func distance(to: SCNVector3) -> Float {
		let vector = SCNVector3(x - to.x, y - to.y, z - to.z)
		return sqrt(pow(vector.x,2) + pow(vector.y, 2) + pow(vector.z, 2))
	}
	func vector(toReachVector: SCNVector3) -> (x: Float, z: Float, angle: Float) {
		let dx = toReachVector.x - x
		let dz = toReachVector.z - z
		let angle = atan2(dz, dx)
		
		let vx = cos(angle)
		let vz = sin(angle)
		
		return (vx, vz, angle)
	}
}

extension Float {
	var fixedRotationAngle: Float {
		return (Float.pi / 2) - self
	}
}
