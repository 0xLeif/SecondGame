//
//   Player.swift
//  SecondGame
//
//  Created by Zach Eriksen on 1/29/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import Foundation
import SceneKit

enum PlayerAnimationState {
	case walk
	case attack
	case dead
}

class Player: SCNNode {
	
	//nodes
	private var daeHelperNode = SCNNode()
	private var characterNode: SCNNode!
	private var collider: SCNNode!
	
	//animation
	private var walkAnimation = CAAnimation()
	private var attackAnimation = CAAnimation()
	private var deadAnimation = CAAnimation()
	
	private var previousUpdateTime = TimeInterval(0.0)
	private var isWalking: Bool = false {
		didSet {
			if oldValue != isWalking {
				if isWalking {
					characterNode.addAnimation(walkAnimation, forKey: "walk")
				} else {
					characterNode.removeAnimation(forKey: "walk", blendOutDuration: 0.2)
				}
			}
		}
	}
	private var directionAngle: Float = 0.0 {
		didSet {
			if directionAngle != oldValue {
				runAction(SCNAction.rotateTo(x: 0.0, y: CGFloat(directionAngle), z: 0.0, duration: 0.1, usesShortestUnitArc: true))
			}
		}
	}
	//collisions
	var replacementPosition: SCNVector3 = SCNVector3Zero
	//battle
	var isDead = false
	private let maxHpPoints: Float = 100
	private var hpPoints: Float = 100
	
	//MARK: init
	override init() {
		super.init()
		
		setupModel()
		loadAnimations()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}
	
	//MARK: scene
	private func setupModel() {
		//load dae childs
		let playerURL = Bundle.main.url(forResource: "art.scnassets/Scenes/Hero/idle", withExtension: "dae")
		let playerScene = try! SCNScene(url: playerURL!, options: nil)
		
		playerScene.rootNode.childNodes.forEach{ daeHelperNode.addChildNode($0) }
		
		addChildNode(daeHelperNode)
		
		//set mesh name
		characterNode = daeHelperNode.childNode(withName: "Bip01", recursively: true)!
	}
	
	//MARK: Animations
	private func loadAnimations() {
		loadAnimation(state: .walk, inScene: "art.scnassets/Scenes/Hero/walk", withID: "WalkID")
		
		loadAnimation(state: .attack, inScene: "art.scnassets/Scenes/Hero/attack", withID: "attackID")
		
		loadAnimation(state: .dead, inScene: "art.scnassets/Scenes/Hero/die", withID: "DeathID")
	}
	
	private func loadAnimation(state: PlayerAnimationState, inScene name: String, withID id: String) {
		let sceneURL = Bundle.main.url(forResource: name, withExtension: "dae")!
		let sceneSource = SCNSceneSource(url: sceneURL, options: nil)!
		
		let animation: CAAnimation = sceneSource.entryWithIdentifier(id, withClass: CAAnimation.self)!
		
		animation.delegate = self
		animation.fadeInDuration = 0.2
		animation.fadeOutDuration = 0.2
		animation.usesSceneTimeBase = false
		animation.repeatCount = 0
		
		switch state {
			case .walk:
				animation.repeatCount = Float.greatestFiniteMagnitude
				walkAnimation = animation
			case .dead:
				animation.isRemovedOnCompletion = false
				deadAnimation = animation
			case .attack:
				animation.setValue("attack1", forKey: "animationID")
				attackAnimation = animation
		}
	}
	//MARK: Movement
	func walk(direction: float3, time: TimeInterval, scene: SCNScene) {
		if isDead { return }
		
		if previousUpdateTime == 0.0 { previousUpdateTime = time }
		
		let deltaTime = Float(min(time - previousUpdateTime, 1.0 / 60.0))
		let speed = deltaTime * 1.3
		previousUpdateTime = time
		
		let initialPosition = position
		
		if direction.x != 0.0 && direction.z != 0.0 {
			// move character
			let pos = float3(position)
			position = SCNVector3(pos + direction * speed)
			
			// update rotation
			directionAngle = SCNFloat(atan2f(direction.x, direction.z))
			
			isWalking = true
		} else {
			isWalking = false
		}
		
		// update altitude
		var pos = position
		var endpoint0 = pos
		var endpoint1 = pos
		
		endpoint0.y -= 0.1
		endpoint1.y += 0.08
		
		let results = scene.physicsWorld.rayTestWithSegment(from: endpoint1, to: endpoint0, options: [.collisionBitMask: BitmaskWall, .searchMode: SCNPhysicsWorld.TestSearchMode.closest])
		
		if let result = results.first {
			let groundAltitude = result.worldCoordinates.y
			pos.y = groundAltitude
			
			position = pos
		} else {
			position = initialPosition
		}
	}
	
	//MARK: collisions
	func setupCollider(withScale scale: CGFloat) {
		let geometry = SCNCapsule(capRadius: 47, height: 165)
		
		collider = SCNNode(geometry: geometry)
		collider.position = SCNVector3(0, 140, 0)
		collider.name = "collider"
		collider.opacity = 0
		
		let physicsGeometry = SCNCapsule(capRadius: 47*scale, height: 165*scale)
		let physicsShape = SCNPhysicsShape(geometry: physicsGeometry, options: nil)
		collider.physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
		collider.physicsBody?.categoryBitMask = BitmaskPlayer
		collider.physicsBody?.contactTestBitMask = BitmaskWall
		
		addChildNode(collider)
	}
	
	//MARK: battle
	func gotHit(forDMG dmg: Float) {
		hpPoints -= dmg
		
		NotificationCenter.default.post(name: NSNotification.Name("hpChanged"), object: nil, userInfo: ["playerMaxHp": maxHpPoints, "currentHp": hpPoints])
		
		if hpPoints <= 0 {
			die()
		}
	}
	private func die() {
		isDead = true
		characterNode.removeAllActions()
		characterNode.removeAllAnimations()
		characterNode.addAnimation(deadAnimation, forKey: "dead")
	}
}

//MARK: Extensions

extension Player: CAAnimationDelegate {
	
}
