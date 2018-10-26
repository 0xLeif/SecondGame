//
//  Environment.swift
//  SecondGame
//
//  Created by Zach Eriksen on 10/22/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import SceneKit

enum EnvironmentType: String, CaseIterable {
    case grass
    case rock
    case fence
}

class Environment: SCNNode {
    var type: EnvironmentType
    var node: SCNNode?
    
    init(type: EnvironmentType) {
        self.type = type
        super.init()
        setupModelScene()
        setupCollider()
    }
    
    private func setupModelScene() {
        let name = type.rawValue
        
        let url = Bundle.main.url(forResource: "art.scnassets/Scenes/Items/\(name)", withExtension: "scn")
        
        let scene = try! SCNScene(url: url!, options: nil)
        
        node = scene.rootNode.childNode(withName: "obj", recursively: true)
        
        addChildNode(node!)
    }
    
    private func setupCollider() {
        
        let physicsShape = SCNPhysicsShape(node: node!, options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron as NSString])
        physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        physicsBody?.categoryBitMask = BitmaskWall
        physicsBody?.contactTestBitMask = BitmaskPlayer
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
