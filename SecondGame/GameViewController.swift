//
//  GameViewController.swift
//  SecondGame
//
//  Created by Zach Eriksen on 1/23/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import UIKit
import SceneKit
import GameplayKit

let BitmaskPlayer = 1
let BitmaskPlayerWeapon = 2
let BitmaskWall = 64
let BitmaskGolem = 3

enum GameState {
	case loading, playing
}

class GameViewController: UIViewController {
	// Scene
	var gameView: GameView { return view as! GameView }
	var mainScene: SCNScene!
	// Variables
	var state: GameState = .loading
	// Nodes
	private var player: Player?
	private var cameraStick: SCNNode!
	private var cameraXHolder: SCNNode!
	private var cameraYHolder: SCNNode!
	private var lightStick: SCNNode!
	// Movement
	private var controllerStoredDirection = float2(0.0)
	private var padTouch: UITouch?
	private var cameraTouch: UITouch?
	// Collisions
	private var maxPenetrationDistance = CGFloat(0.0)
	private var replacementPositions = [SCNNode: SCNVector3]()
	// Calculated Variables
	var characterDirection: float3 {
		var direction = float3(controllerStoredDirection.x, 0.0, controllerStoredDirection.y)
		if let pov = gameView.pointOfView {
			let p1 = pov.presentation.convertPosition(SCNVector3(direction), to: nil)
			let p0 = pov.presentation.convertPosition(SCNVector3Zero, to: nil)
			
			direction = float3(Float(p1.x - p0.x),
							   0.0,
							   Float(p1.z - p0.z))
			
			if direction.x != 0.0 || direction.z != 0.0 {
				direction = normalize(direction)
			}
		}
		return direction
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		setupScene()
		setupPlayer()
		setupCamera()
		setupLight()
		setupWallBitmasks()
		
		state = .playing
    }
	
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
	
	//MARK: Scene
	private func setupScene() {
		gameView.antialiasingMode = .multisampling4X
		gameView.delegate = self
		
		mainScene = SCNScene(named: "art.scnassets/Scenes/Stage1.scn")
		mainScene.physicsWorld.contactDelegate = self
		
		gameView.scene = mainScene
		gameView.isPlaying = true
	}
	//MARK: Player
	private func setupPlayer() {
		player = Player()
		player?.scale = SCNVector3(0.0026, 0.0026, 0.0026)
		player?.position = SCNVector3Zero
		player?.rotation = SCNVector4(0, 1, 0, Float.pi)
		
		mainScene.rootNode.addChildNode(player!)
		
		player!.setupCollider(withScale: 0.0026)
	}
	//MARK: Walls
	private func setupWallBitmasks() {
		var collisionNodes = [SCNNode]()
		
		mainScene.rootNode.enumerateChildNodes { (node, _) in
			switch node.name {
			case let .some(s) where s.range(of: "collision") != nil:
				collisionNodes.append(node)
			default: break
			}
		}
		for node in collisionNodes {
			node.physicsBody = SCNPhysicsBody.static()
			node.physicsBody!.categoryBitMask = BitmaskWall
			node.physicsBody!.physicsShape = SCNPhysicsShape(node: node, options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron as NSString])
		}
	}
	//MARK: Camera
	private func setupCamera() {
		cameraStick = mainScene.rootNode.childNode(withName: "CameraStick", recursively: false)!
		cameraXHolder = mainScene.rootNode.childNode(withName: "xHolder", recursively: true)!
		cameraYHolder = mainScene.rootNode.childNode(withName: "yHolder", recursively: true)!
	}
	private func panCamera(direction: float2) {
		var directionToPan = direction
		directionToPan *= float2(1.0, -1.0)
		
		let panReducer = Float(0.005)
		
		let currX = cameraXHolder.rotation
		let xRotationValue = currX.w - directionToPan.x * panReducer
		
		let currY = cameraYHolder.rotation
		var yRotationValue = currY.w - directionToPan.y * panReducer
		
		if yRotationValue < -0.94 { yRotationValue = -0.94 }
		if yRotationValue > 0.66 { yRotationValue = 0.66 }
		
		cameraXHolder.rotation = SCNVector4(0, 1, 0, xRotationValue)
		cameraYHolder.rotation = SCNVector4(1, 0, 0, yRotationValue)
	}
	private func setupLight() {
		lightStick = mainScene.rootNode.childNode(withName: "LightStick", recursively: false)!
	}
	//MARK: Touches & Movement
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		for touch in touches {
			if gameView.virtualDPadBounds().contains(touch.location(in: gameView)){
				if padTouch == nil {
					padTouch = touch
					controllerStoredDirection = float2(0.0)
				}
			} else if cameraTouch == nil {
				cameraTouch = touches.first
			}
			if padTouch != nil { break }
		}
	}
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesMoved(touches, with: event)
		if let touch = padTouch {
			let displacement = float2(touch.location(in: view)) - float2(touch.previousLocation(in: view))
			
			let vMix = mix(controllerStoredDirection, displacement, t: 0.1)
			let vClamp = clamp(vMix, min: -1.0, max: 1.0)
			
			controllerStoredDirection = vClamp
			
			print(controllerStoredDirection)
		} else if let touch = cameraTouch {
			let displacement = float2(touch.location(in: view)) - float2(touch.previousLocation(in: view))
			
			panCamera(direction: displacement)
		}
	}
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)
		padTouch = nil
		cameraTouch = nil
		controllerStoredDirection = float2(0.0)
	}
	
	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesEnded(touches, with: event)
		padTouch = nil
		cameraTouch = nil
		controllerStoredDirection = float2(0.0)
	}
	//MARK: Game Loop Functions
	func updateFollowersPositions() {
		let pos = SCNVector3(player!.position.x, 0.0, player!.position.z)
		cameraStick.position = pos
		lightStick.position = pos
	}
	//MARK: Enemies

}

//MARK: Extensions

// game loop
extension GameViewController: SCNSceneRendererDelegate {
	func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
		if state != .playing { return }
		
		for (node, pos) in replacementPositions {
			node.position = pos
		}
	}
	
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		if state != .playing { return }
		
		// reset
		replacementPositions.removeAll()
		maxPenetrationDistance = 0.0
		
		let scene = gameView.scene!
		let direction = characterDirection
		
		player?.walk(direction: direction, time: time, scene: scene)
		
		updateFollowersPositions()
	}
	
	//MARK: collisions:
	private func characterNode(_ node: SCNNode, hitWall wall: SCNNode, withContact contact: SCNPhysicsContact) {
		if node.name != "collider" { return }
		
		if maxPenetrationDistance > contact.penetrationDistance { return }
		
		maxPenetrationDistance = contact.penetrationDistance
		
		var characterPosition = float3(node.parent!.position)
		var positionOffset = float3(contact.contactNormal) * Float(contact.penetrationDistance)
		positionOffset.y = 0
		characterPosition += positionOffset
		
		replacementPositions[node.parent!] = SCNVector3(characterPosition)
	}
	//MARK: enemies
}
// physics
extension GameViewController: SCNPhysicsContactDelegate {
	func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
		if state != .playing { return }
		
		contact.match(BitmaskWall) { (matching, other) in
			self.characterNode(other, hitWall: matching, withContact: contact)
		}
	}
	func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {
		contact.match(BitmaskWall) { (matching, other) in
			self.characterNode(other, hitWall: matching, withContact: contact)
		}
	}
	func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
		
	}
}
