//
//  Golem.swift
//  SecondGame
//
//  Created by Zach Eriksen on 2/5/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import Foundation
import SceneKit

enum GolemAnimationType {
	case walk, attack, dead
}

class Golem: SCNNode {
	// general
	var gameView: GameView!
	// nodes
	private let daeHolderNode = SCNNode()
	private var characterNode: SCNNode!
	private var enemy: Player!
	private var collider: SCNNode!
	// animations
	private var walkAnimation = CAAnimation()
	private var attackAnimation = CAAnimation()
	private var deadAnimation = CAAnimation()
	// movement
	private var previousUpdateTime: TimeInterval = 0
	private let noticeDistance: Float = 1.4
	private let movementSpeedLimiter: Float = 0.5
	// attack
	private var isAttacking = false
	private var lastAttackTime: TimeInterval = 0
	private var attackTimer: Timer?
	private var attackFrameCounter = 0

	private var isWalking: Bool = false {
		didSet {
			oldValue != isWalking ? addAnimation(walkAnimation, forKey: "walk") : removeAnimation(forKey: "walk")
		}
	}
	var isCollideWithEnemy: Bool = false {
		didSet {
			if oldValue != isCollideWithEnemy {
				if isCollideWithEnemy {
					isWalking = false
				}
			}
		}
	}
	//MARK: init
	init(enemy: Player, view: GameView) {
		super.init()
		self.enemy = enemy
		gameView = view
		setupModelScene()
		loadAnimations()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	//MARK: scene
	private func setupModelScene() {
		name = "Golem"
		
		let idleURL = Bundle.main.url(forResource: "art.scnassets/Scenes/Enemies/Golem@Idle", withExtension: "dae")
		let idleScene = try! SCNScene(url: idleURL!, options: nil)
		
		idleScene.rootNode.childNodes.forEach{ daeHolderNode.addChildNode($0) }
		
		addChildNode(daeHolderNode)
		
		characterNode = daeHolderNode.childNode(withName: "CATRigHub002", recursively: true)!
	}
	
	//MARK: Animations
	private func loadAnimations() {
		loadAnimation(state: .walk, inScene: "art.scnassets/Scenes/Enemies/Golem@Flight", withID: "unnamed_animation__1")
		
		loadAnimation(state: .attack, inScene: "art.scnassets/Scenes/Enemies/Golem@Attack", withID: "Golem@Attack(1)-1")
		
		loadAnimation(state: .dead, inScene: "art.scnassets/Scenes/Enemies/Golem@Dead", withID: "Golem@Dead-1")
	}
	
	private func loadAnimation(state: GolemAnimationType, inScene name: String, withID id: String) {
		let sceneURL = Bundle.main.url(forResource: name, withExtension: "dae")!
		let sceneSource = SCNSceneSource(url: sceneURL, options: nil)!
		
		guard let animation: CAAnimation = sceneSource.entryWithIdentifier(id, withClass: CAAnimation.self) else {
			return
		}
		
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
			animation.setValue("attack", forKey: "animationID")
			attackAnimation = animation
		}
	}
	//MARK: movement
	func update(withTime time: TimeInterval, andScene scene: SCNScene) {
		guard let enemy = enemy, !enemy.isDead else { return }
		
		//delta time
		if previousUpdateTime == 0 { previousUpdateTime = time }
		let deltaTime = Float(min(time - previousUpdateTime, 1/60))
		previousUpdateTime = time
		
		//get distance
		let distance = position.distance(to: enemy.position)
		
		if distance < noticeDistance && distance > 0.01 {
			let result = position.vector(toReachVector: enemy.position)
			let (x, z, angle) = (result.x, result.z, result.angle)
			
			//rotate
			let rotationAngle = angle.fixedRotationAngle
			eulerAngles = SCNVector3(0, rotationAngle, 0)
			
			if !isCollideWithEnemy && !isAttacking {
				let speed = deltaTime * movementSpeedLimiter
				if x != 0 && z != 0 {
					position.x += x * speed
					position.z += z * speed
					
					isWalking = true
				} else {
					isWalking = false
				}
			} else {
				// attack
				if lastAttackTime == 0 {
					lastAttackTime = time
					attack()
				}
				let timeDiff = time - lastAttackTime
				
				if timeDiff >= 2.5 {
					lastAttackTime = time
					attack()
				}
			}
		} else {
			isWalking = false
		}
		// update altitude
		let initialPosition = position
		
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
	func setupCollider(scale: CGFloat) {
		let geometry = SCNCapsule(capRadius: 13, height: 52)
		
		collider = SCNNode(geometry: geometry)
		collider.name = "golemCollider"
		collider.position = SCNVector3(0, 46, 0)
		collider.opacity = 0
		
		let physicsGeometry = SCNCapsule(capRadius: 13 * scale, height: 52 * scale)
		let physicsShape = SCNPhysicsShape(geometry: physicsGeometry, options: nil)
		collider.physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
		collider.physicsBody?.categoryBitMask = BitmaskGolem
		collider.physicsBody?.contactTestBitMask = BitmaskWall | BitmaskPlayer | BitmaskPlayerWeapon
		
		gameView.prepare([collider]) { (finished) in
			self.addChildNode(self.collider)
		}
	}
	
	//MARK: battle
	private func attack() {
		if isAttacking { return }
		
		isAttacking = true
		
		DispatchQueue.main.async {
			self.attackTimer?.invalidate()
			self.attackTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(self.attackTimerTicked), userInfo: nil, repeats: true)
			
			self.characterNode.addAnimation(self.attackAnimation, forKey: "attack")
		}
	}
	@objc private func attackTimerTicked() {
		attackFrameCounter += 1
		
		if attackFrameCounter == 10 {
			if isCollideWithEnemy {
				enemy.gotHit(forDMG: 15)
			}
		}
	}
}
//MARK: extension
extension Golem: CAAnimationDelegate {
	func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
		guard let id = anim.value(forKey: "animationID") as? String else { return }
		
		if id == "attack" {
			attackTimer?.invalidate()
			attackFrameCounter = 0
			isAttacking = false
		}
		
	}
}
