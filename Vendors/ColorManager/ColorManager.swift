//
//  APColorManager.swift
//  Stage1st
//
//  Created by Zheng Li on 11/12/15.
//  Copyright © 2015 Renaissance. All rights reserved.
//

import UIKit
import CocoaLumberjack

public class APColorManager: NSObject {
    fileprivate var palette: NSDictionary = NSDictionary()
    fileprivate var colorMap: NSDictionary = NSDictionary()
    fileprivate let fallbackColor = UIColor.black
    fileprivate let defaultPaletteURL = Bundle.main.url(forResource: "DarkPalette", withExtension: "plist")

    public static let shared = { return APColorManager() }()

    override init () {
        let paletteName = UserDefaults.standard.bool(forKey: "NightMode") == true ? "DarkPalette": "DefaultPalette"

        let palettePath = Bundle.main.path(forResource: paletteName, ofType: "plist")
        if let palettePath = palettePath,
           let palette = NSDictionary(contentsOfFile: palettePath) {
            self.palette = palette
        }

        let colorMapPath = Bundle.main.path(forResource: "ColorMap", ofType: "plist")
        if let colorMapPath = colorMapPath,
           let colorMap = NSDictionary(contentsOfFile: colorMapPath) {
            self.colorMap = colorMap
        }

        super.init()
    }

    public func switchPalette(_ type: PaletteType) {
        let paletteName: String = type == .night ? "DarkPalette" : "DefaultPalette"
        let paletteURL = Bundle.main.url(forResource: paletteName, withExtension: "plist")
        loadPaletteByURL(paletteURL, shouldPushNotification: true)
    }

    public func htmlColorStringWithID(_ paletteID: String) -> String {
        return (self.palette.value(forKey: paletteID) as? String) ?? "#000000"
    }

    public func isDarkTheme() -> Bool {
        return self.palette.value(forKey: "Dark") as? Bool ?? false
    }

    public func updateGlobalAppearance() {
        UIToolbar.appearance().barTintColor = colorForKey("appearance.toolbar.bartint")
        UIToolbar.appearance().tintColor = colorForKey("appearance.toolbar.tint")
        UINavigationBar.appearance().barTintColor = colorForKey("appearance.navigationbar.bartint")
        UINavigationBar.appearance().tintColor = colorForKey("appearance.navigationbar.tint")
        UINavigationBar.appearance().titleTextAttributes = [NSForegroundColorAttributeName: colorForKey("appearance.navigationbar.title"), NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17.0)]
        UISwitch.appearance().onTintColor = colorForKey("appearance.switch.tint")
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSForegroundColorAttributeName: self.colorForKey("appearance.searchbar.text"), NSFontAttributeName: UIFont.systemFont(ofSize: 14.0)]

        UIScrollView.appearance().indicatorStyle = isDarkTheme() ? .white : .default
        UITextField.appearance().keyboardAppearance = isDarkTheme() ? .dark : .default
        UIApplication.shared.statusBarStyle = isDarkTheme() ? .lightContent : .default
    }

    public func colorForKey(_ key: String) -> UIColor {
        if let paletteID = (self.colorMap.value(forKey: key) as? String) {
            return colorInPaletteWithID(paletteID)
        } else {
            DDLogWarn("[Color Manager] can't found color \(key), default color used")
            return colorInPaletteWithID("default")
        }
    }
}

// MARK: - Private
private extension APColorManager {
    func loadPaletteByURL(_ paletteURL: URL?, shouldPushNotification shouldPush: Bool) {
        guard let paletteURL = paletteURL, let palette = NSDictionary(contentsOf: paletteURL) else {
            return
        }
        self.palette = palette
        updateGlobalAppearance()
        if shouldPush {
            NotificationCenter.default.post(name: .APPaletteDidChangeNotification, object: nil)
        }
    }

    func colorInPaletteWithID(_ paletteID: String) -> UIColor {
        let colorString = self.palette.value(forKey: paletteID) as? String
        if let colorString = colorString, let color = S1Global.color(fromHexString: colorString) {
            return color
        } else {
            return self.fallbackColor
        }
    }
}

// MARK: - Miscs
public extension UIViewController {
    public func didReceivePaletteChangeNotification(_ notification: Notification?) {
    }
}

public extension Notification.Name {
    public static let APPaletteDidChangeNotification = Notification.Name.init(rawValue: "APPaletteDidChangeNotification")
}

@objc public enum PaletteType: NSInteger {
    case day
    case night
}
