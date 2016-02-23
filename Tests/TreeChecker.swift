//
//  TreeChecker.swift
//  RedBlackTree
//
//  Created by Károly Lőrentey on 2015-12-20.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import XCTest
@testable import RedBlackTree

struct RedBlackInfo<Key: RedBlackInsertionKey, Payload> {
    typealias Tree = RedBlackTree<Key, Payload>
    typealias Handle = Tree.Handle
    typealias Summary = Tree.Summary

    var nodeCount: Int = 0
    var leftmost: Handle? = nil
    var rightmost: Handle? = nil

    var minDepth: Int = 0
    var maxDepth: Int = 0

    var minRank: Int = 0
    var maxRank: Int = 0

    var color: Color = .Black
    var summary: Summary = Summary()
    var minKey: Key? = nil
    var maxKey: Key? = nil

    var defects: [(Handle, String, FileString, UInt)] = []

    mutating func addDefect(handle: Handle, _ description: String, file: FileString = __FILE__, line: UInt = __LINE__) {
        defects.append((handle, description, file, line))
    }
}

extension RedBlackTree {
    typealias Info = RedBlackInfo<InsertionKey, Payload>

    private func collectInfo(blacklist: Set<Handle>, handle: Handle?, parent: Handle?, prefix: Summary) -> Info {

        guard let handle = handle else { return Info() }

        var info = Info()
        let node = self[handle]

        if blacklist.contains(handle) {
            info.addDefect(handle, "node is linked more than once")
            return info
        }
        var blacklist = blacklist
        blacklist.insert(handle)

        let li = collectInfo(blacklist, handle: node.left, parent: handle, prefix: prefix)
        let ri = collectInfo(blacklist, handle: node.right, parent: handle, prefix: prefix + li.summary + node.head)
        info.summary = li.summary + node.head + ri.summary

        info.nodeCount = li.nodeCount + 1 + ri.nodeCount

        info.leftmost = li.leftmost ?? handle
        info.rightmost = ri.rightmost ?? handle

        info.minDepth = min(li.minDepth, ri.minDepth) + 1
        info.maxDepth = max(li.maxDepth, ri.maxDepth) + 1
        info.minRank = min(li.minRank, ri.minRank) + (node.color == .Black ? 1 : 0)
        info.maxRank = max(li.maxRank, ri.maxRank) + (node.color == .Black ? 1 : 0)

        info.defects = li.defects + ri.defects
        info.color = node.color

        if node.parent != parent {
            info.addDefect(handle, "parent is \(node.parent), expected \(parent)")
        }
        if node.color == .Red {
            if li.color != .Black {
                info.addDefect(handle, "color is red but left child(\(node.left) is also red")
            }
            if ri.color != .Black {
                info.addDefect(handle, "color is red but right child(\(node.left) is also red")
            }
        }
        if li.minRank != ri.minRank {
            info.addDefect(handle, "mismatching child subtree ranks: \(li.minRank) vs \(ri.minRank)")
        }
        if info.summary != node.summary {
            info.addDefect(handle, "summary is \(node.summary), expected \(info.summary)")
        }
        let key = InsertionKey(summary: prefix + li.summary, head: node.head)
        info.maxKey = ri.maxKey
        info.minKey = li.minKey
        if let lk = li.maxKey where lk > key {
            info.addDefect(handle, "node's key is ordered before its maximum left descendant: \(key) < \(lk)")
        }
        if let rk = ri.minKey where rk < key {
            info.addDefect(handle, "node's key is ordered after its minimum right descendant: \(key) > \(rk)")
        }
        return info
    }

    var debugInfo: Info {
        var info = collectInfo([], handle: root, parent: nil, prefix: Summary())
        if info.color == .Red {
            info.addDefect(root!, "root is red")
        }
        if info.nodeCount != count {
            info.addDefect(root!, "count of reachable nodes is \(count), expected \(info.nodeCount)")
        }
        if info.leftmost != leftmost {
            info.addDefect(leftmost ?? info.leftmost!, "leftmost node is \(leftmost), expected \(info.leftmost)")
        }
        if info.rightmost != rightmost {
            info.addDefect(rightmost ?? info.rightmost!, "rightmost node is \(rightmost), expected \(info.rightmost)")
        }
        return info
    }

    func assertValid() {
        let info = debugInfo
        for (handle, explanation, file, line) in info.defects {
            XCTFail("\(handle): \(explanation)", file: file, line: line)
        }
    }
}
