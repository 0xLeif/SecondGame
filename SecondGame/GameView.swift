//
//  GameView.swift
//  SecondGame
//
//  Created by Zach Eriksen on 1/23/18.
//  Copyright © 2018 oneleif. All rights reserved.
//

import SceneKit
import SpriteKit

class GameView: SCNView {
	private var skScene: SKScene!
	private var dpadSprite: SKSpriteNode!
	private var attackSprite: SKSpriteNode!
	private var healthBarSprite: SKSpriteNode!
	
	private let healthBarWidth: CGFloat = 150
	
	private let overlayNode = SKNode()
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		setupGUI()
		setupNotificationObserver()
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		layoutGUI()
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	//MARK: Overlay
	private func setupGUI() {
		let height = bounds.size.height
		
		skScene = SKScene(size: bounds.size)
		skScene.scaleMode = .resizeFill
		
		skScene.addChild(overlayNode)
		overlayNode.position = CGPoint(x: 0, y: height)
		
		setupDPad(with: skScene)
		setupAttackButton(with: skScene)
		setupHealthBar(with: skScene)
		
		overlaySKScene = skScene
		skScene.isUserInteractionEnabled = false
	}
	
	private func layoutGUI() {
		overlayNode.position = CGPoint(x: 0, y: bounds.size.height)
	}
	//MARK: D-Pad
	private func setupDPad(with scene: SKScene) {
		dpadSprite = SKSpriteNode(imageNamed: "art.scnassets/Assets/dpad.png")
		dpadSprite.position = CGPoint(x: 10, y: 10)
		(dpadSprite.xScale, dpadSprite.yScale) = (1,1)
		dpadSprite.anchorPoint = .zero
		dpadSprite.size = CGSize(width: 150, height: 150)
		scene.addChild(dpadSprite)
	}
	func virtualDPadBounds() -> CGRect {
		var virtualDPadBounds = CGRect(x: 10, y: 10, width: 150, height: 150)
		virtualDPadBounds.origin.y = bounds.size.height - virtualDPadBounds.size.height
		return virtualDPadBounds
	}
	//MARK: Attack Button
	func setupAttackButton(with scene: SKScene) {
		attackSprite = SKSpriteNode(imageNamed: "art.scnassets/Assets/attack1.png")
		attackSprite.position = CGPoint(x: bounds.height - 60, y: 50)
		(attackSprite.xScale, attackSprite.yScale) = (1,1)
		attackSprite.anchorPoint = .zero
		attackSprite.name = "attack"
		attackSprite.size = CGSize(width: 60, height: 60)
		scene.addChild(attackSprite)
	}
	func virtualAttackButtonBounds() -> CGRect {
		var virtualAttackButtonBounds = CGRect(x: bounds.height - 60, y: 50, width: 60, height: 60)
		virtualAttackButtonBounds.origin.y = bounds.size.height - virtualAttackButtonBounds.size.height
		return virtualAttackButtonBounds
	}
	//MARK: Health Bar
	func setupHealthBar(with scene: SKScene) {
		healthBarSprite = SKSpriteNode(color: .green, size: CGSize(width: healthBarWidth, height: 20))
		healthBarSprite.anchorPoint = .zero
		healthBarSprite.position = CGPoint(x: 15, y: bounds.width)
		(healthBarSprite.xScale, healthBarSprite.yScale) = (1,1)
		scene.addChild(healthBarSprite)
	}
	
	//MARK: Internal functions
	private func setupNotificationObserver() {
		NotificationCenter.default.addObserver(self, selector: #selector(hpDidChange), name: NSNotification.Name("hpChanged"), object: nil)
	}
	
	@objc private func hpDidChange(sender: NSNotification) {
		guard let data = sender.userInfo as? [String: Any],
			let maxHp = data["playerMaxHp"] as? Float,
			let hp = data["currentHp"] as? Float else {
				return
		}
		var width = (healthBarWidth * CGFloat(hp)) / CGFloat(maxHp)
		
		if width < 0 { width = 0 }
		
		if width <= healthBarWidth / 3.5 {
			healthBarSprite.color = .red
		} else if width <= healthBarWidth / 2 {
			healthBarSprite.color = .orange
		}
		
		let reduceAction = SKAction.resize(toWidth: width, duration: 0.3)
		healthBarSprite.run(reduceAction)
	}
}
