//
//  RedBlackTree descriptions.swift
//  RedBlackTree
//
//  Created by Károly Lőrentey on 2015-12-19.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import Foundation

extension RedBlackTree: CustomStringConvertible {
    public var description: String {
        return "RedBlackTree with \(count) nodes"
    }
}