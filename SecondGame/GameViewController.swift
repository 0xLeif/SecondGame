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
	// Enemies
	private var golemsPositions = [String: SCNVector3]()
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
        setupInitEnvironment()
		setupPlayer()
		setupCamera()
		setupLight()
		setupWallBitmasks()
		setupEnemies()
		state = .playing
        for _ in (0 ... 10) {
            
            createGolem(atPosition: SCNVector3(Int.random(in: -10 ... 10), 0, Int.random(in: -10 ... 10)))
        }
        
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
    
    func environment(forValue value: Float) -> EnvironmentType? {
//        print("\t\t\(value)")
        switch value {
        case 0.21 ... 0.3:
            return .fence
        case 0.11 ... 0.2:
            return .rock
        case 0 ... 0.1:
            return .grass
        default: break
        }
        return nil
    }
    
    var map: [Environment] = []
    var start: Date!
    var end: Date!
    private func gen(from: vector_int2, objectCount: Int32 = 10, bound: Int32 = 5) {
        start = Date()
        print(start)
        print("STARTING PERLIN GEN")
        let perlin = GKPerlinNoiseSource()
        let perlinNoise = GKNoise(perlin)
        let perlinMap = GKNoiseMap(perlinNoise)
        print("DONE CREATING PERLIN MAP")
        print("STARTING X Z VALUES FROM BOUNDS")
        for _ in 1 ... objectCount {
            let xOffset = Int32.random(in: -bound ... bound) + from.x
            let yOffset = Int32.random(in: -bound ... bound) + from.y
            let value = perlinMap.value(at: vector_int2(xOffset, yOffset))
            if let type = environment(forValue: value) {
                let node = Environment(type: type)
                node.position = SCNVector3(Int(xOffset), 0, Int(yOffset))
                map.append(node)
            }
        }
        print("DONE GENERATING NODES")
        print("SPAWNING NODES")
        for m in map {
            mainScene.rootNode.addChildNode(m)
        }
        print("DONE SPAWNING NODES")
        end = Date()
        print(end.timeIntervalSince1970 - start.timeIntervalSince1970)
    }
    
    private func ranGen() {
        let bound = 10
        for _ in (0 ... 10) {
            for type in EnvironmentType.allCases {
                let obj = Environment(type: type)
                obj.position = SCNVector3(Int.random(in: -bound ... bound), 0, Int.random(in: -bound ... bound))
                mainScene.rootNode.addChildNode(obj)
            }
        }
    }
    
    private func setupInitEnvironment() {
//        var x: CGFloat = 0
        gen(from: vector_int2(x: 0, y: 0), objectCount: 100)
     
//        ranGen()
//        EnvironmentType.allCases.forEach { (type) in
//            let obj = Environment(type: type)
//            obj.position = SCNVector3(x, 0, 1)
//            mainScene.rootNode.addChildNode(obj)
//            x += 2.5
//        }
    }
	
	//MARK: Scene
	private func setupScene() {
		gameView.antialiasingMode = .multisampling4X
		gameView.delegate = self
		
		mainScene = SCNScene(named: "art.scnassets/Scenes/Stage2.scn")
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
		player!.setupWeaponCollider(withScale: 0.0026)
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
			} else if gameView.virtualAttackButtonBounds().contains(touch.location(in: gameView)) {
				player?.attack()
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
		
		// golems
		mainScene.rootNode.enumerateChildNodes { (node, _) in
			if let golem = node as? Golem {
				golem.update(withTime: time, andScene: scene)
			}
		}
	}
	
	//MARK: collisions:
	private func characterNode(_ node: SCNNode, hitWall wall: SCNNode, withContact contact: SCNPhysicsContact) {
		if node.name != "collider" && node.name != "golemCollider" { return }
		
		if maxPenetrationDistance > contact.penetrationDistance { return }
		
		maxPenetrationDistance = contact.penetrationDistance
		
		var characterPosition = float3(node.parent!.position)
		var positionOffset = float3(contact.contactNormal) * Float(contact.penetrationDistance)
		positionOffset.y = 0
		characterPosition += positionOffset
		
		replacementPositions[node.parent!] = SCNVector3(characterPosition)
	}
	//MARK: enemies
	private func setupEnemies() {
//        let enemies = mainScene.rootNode.childNode(withName: "Enemies", recursively: false)!
//        enemies.childNodes.forEach{ golemsPositions[$0.name!] = $0.position }
		
//        setupGolems()
	}
	
	private func setupGolems() {
		let golemNames = ["golem1","golem2","golem3","golem4"]
		let golemScale: Float = 0.0083
		func loadGolem(name: String) -> Golem {
			let golem = Golem(enemy: player!, view: gameView)
			golem.scale = SCNVector3(golemScale, golemScale, golemScale)
			golem.position = golemsPositions[name]!
			return golem
		}
		let golems = golemNames.map{ loadGolem(name: $0) }
		gameView.prepare(golems) { (finished) in
			golems.forEach{
				$0.setupCollider(scale: CGFloat(golemScale))
				self.mainScene.rootNode.addChildNode($0)
			}
		}
	}
    
    private func createGolem(atPosition position: SCNVector3) {
        let golemScale: Float = 0.0083
        let golem = Golem(enemy: player!, view: gameView)
        golem.scale = SCNVector3(golemScale, golemScale, golemScale)
        golem.position = position
        golem.setupCollider(scale: CGFloat(golemScale))
        
        mainScene.rootNode.addChildNode(golem)
    }
}
// physics
extension GameViewController: SCNPhysicsContactDelegate {
	private func updatePhsyicsWorld(contact: SCNPhysicsContact) {
		contact.match(BitmaskWall) { (matching, other) in
			self.characterNode(other, hitWall: matching, withContact: contact)
		}
		
		contact.match(BitmaskGolem){ (matching, other) in
			let golem = matching.parent as! Golem
			if other.name == "collider" { golem.isCollideWithEnemy = true }
			if other.name == "weaponCollider" { player!.weaponCollide(withNode: golem) }
		}
	}
	
	func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
		if state != .playing { return }
		
		updatePhsyicsWorld(contact: contact)
	}
	func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {
		updatePhsyicsWorld(contact: contact)
	}
	func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
		contact.match(BitmaskGolem){ (matching, other) in
			let golem = matching.parent as! Golem
			if other.name == "collider" { golem.isCollideWithEnemy = false }
			if other.name == "weaponCollider" { player!.weaponUnCollide(withNode: golem) }
		}
	}
}
