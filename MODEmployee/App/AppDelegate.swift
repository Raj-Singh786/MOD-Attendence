//
//  AppDelegate.swift
//  MODEmployee
//
//  Created by Rajpal singh on 12/10/26.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
//        // Create window
//        window = UIWindow(frame: UIScreen.main.bounds)
//        
//        // Setup root view controller
//        let loginVC = LoginViewController()
//        let navigationController = UINavigationController(rootViewController: loginVC)
//        
//        window?.rootViewController = navigationController
//        window?.makeKeyAndVisible()
        
        return true
    }
    
    // MARK: - Scene Lifecycle (iOS 13+)
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
