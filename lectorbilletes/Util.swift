//
//  Util.swift
//  lectorbilletes
//
//  Created by Christian Quicano on 1/21/20.
//  Copyright © 2020 christianquicano. All rights reserved.
//

import Foundation

class Util {

    static let keyNoShow = "noShow"

    static func getBool(_ key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }

    static func saveBool(_ key: String, bool: Bool) {
        UserDefaults.standard.set(bool, forKey: key)
        UserDefaults.standard.synchronize()
    }
}
