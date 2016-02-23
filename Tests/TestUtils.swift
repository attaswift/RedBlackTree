//
//  TestUtils.swift
//  RedBlackTree
//
//  Created by Károly Lőrentey on 2015-12-15.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import XCTest
@testable import RedBlackTree


extension RedBlackTree {

    func show() -> String {
        func show(handle: Handle?, prefix: Summary) -> String {
            guard let handle = handle else { return "" }
            let node = self[handle]

            var s = prefix
            let left = show(node.left, prefix: s)

            s += self[node.left]?.summary
            let root = String(InsertionKey(summary: s, head: node.head))

            s += node.head
            let right = show(node.right, prefix: s)
            return "(" + [left, root, right].filter { !$0.isEmpty }.joinWithSeparator(" ") + ")"
        }
        return show(root, prefix: Summary())
    }

    func showNode(handle: Handle) -> String {
        let node = self[handle]
        return "\(handle): \(node.summary) ⟼ \(node.payload)"
    }
    func showNode(i: Int) -> String {
        let node = nodes[i]
        return "#\(i): \(node.summary) ⟼ \(node.payload)"
    }

    func lookup(directions: RedBlackDirection...) -> Handle? {
        return self.lookup(directions)
    }

    func lookup<S: SequenceType where S.Generator.Element == RedBlackDirection>(directions: S) -> Handle? {
        var handle = self.root
        for direction in directions {
            guard let h = handle else { return nil }
            handle = self[h][direction]
        }
        return handle
    }

}

