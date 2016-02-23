//
//  RedBlackTree.swift
//  RedBlackTree
//
//  Created by Károly Lőrentey on 2015-12-17.
//  Copyright © 2015–2016 Károly Lőrentey.
//

import Foundation

public struct RedBlackHandle<Key: RedBlackInsertionKey, Payload>: Hashable {
    private let index: Int

    private init(_ index: Int) {
        self.index = index
    }

    public var hashValue: Int { return index.hashValue }
}

public func ==<K: RedBlackKey, P>(a: RedBlackHandle<K, P>, b: RedBlackHandle<K, P>) -> Bool {
    return a.index == b.index
}

extension RedBlackHandle: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "#\(self.index)"
    }
    public var debugDescription: String {
        return "#\(self.index)"
    }
}

internal enum Color {
    case Red
    case Black
}

private enum KeyMatchResult {
    case Before
    case Matching
    case After
}

/// A direction represents a choice between a left and right child in a binary tree.
public enum RedBlackDirection {
    /// The left child.
    case Left
    /// The right child.
    case Right

    /// The opposite direction.
    var opposite: RedBlackDirection {
        switch self {
        case .Left: return .Right
        case .Right: return .Left
        }
    }
}

/// A slot in the binary tree represents a place into which you can put a node.
/// The tree's root is one slot, and so is either child of another node.
internal enum RedBlackSlot<Key: RedBlackInsertionKey, Payload>: Equatable {
    internal typealias Handle = RedBlackHandle<Key, Payload>

    /// A slot representing the place of the topmost node in the tree.
    case Root
    /// A slot representing the child towards a certain direction under a certain parent node in the tree.
    case Toward(RedBlackDirection, under: Handle)
}
internal func ==<Key: RedBlackKey, Payload>(a: RedBlackSlot<Key, Payload>, b: RedBlackSlot<Key, Payload>) -> Bool {
    return a == b
}

private struct _Handle<Key: RedBlackInsertionKey, Payload> {
    typealias Handle = RedBlackHandle<Key, Payload>

    var _index: UInt32

    init(_ handle: Handle?) {
        if let handle = handle { _index = UInt32(handle.index) }
        else { _index = UInt32.max }
    }

    var handle: Handle? {
        get {
            return (_index == UInt32.max ? nil : Handle(Int(_index)))
        }
        set(handle) {
            if let handle = handle { _index = UInt32(handle.index) }
            else { _index = UInt32.max }
        }
    }
}


internal struct RedBlackNode<Key: RedBlackInsertionKey, Payload> {
    typealias Handle = RedBlackHandle<Key, Payload>
    typealias Summary = Key.Summary
    typealias Head = Summary.Item

    private var _parent: _Handle<Key, Payload>
    private var _left: _Handle<Key, Payload>
    private var _right: _Handle<Key, Payload>
    private(set) var color: Color

    private(set) var head: Head
    private(set) var summary: Summary

    private(set) var payload: Payload


    private init(parent: Handle?, head: Head, payload: Payload) {
        self._parent = _Handle(parent)
        self._left = _Handle(nil)
        self._right = _Handle(nil)
        self.head = head
        self.summary = Summary(head)
        self.payload = payload
        self.color = .Red
    }

    internal subscript(direction: RedBlackDirection) -> Handle? {
        get {
            switch direction {
            case .Left: return left
            case .Right: return right
            }
        }
        mutating set(handle) {
            switch direction {
            case .Left: left = handle
            case .Right: right = handle
            }
        }
    }

    internal private(set) var parent: Handle? {
        get { return _parent.handle }
        set(h) { _parent.handle = h }
    }
    internal private(set) var left: Handle? {
        get { return _left.handle }
        set(h) { _left.handle = h }
    }
    internal private(set) var right: Handle? {
        get { return _right.handle }
        set(h) { _right.handle = h }
    }

    private mutating func replaceChild(old: Handle, with new: Handle?) {
        if left == old {
            left = new
        }
        else {
            assert(right == old)
            right = new
        }
    }
}

public struct RedBlackTree<InsertionKey: RedBlackInsertionKey, Payload> {
    //MARK: Type aliases

    public typealias Handle = RedBlackHandle<InsertionKey, Payload>
    public typealias Summary = InsertionKey.Summary
    public typealias Head = Summary.Item
    public typealias Element = (InsertionKey, Payload)

    internal typealias Node = RedBlackNode<InsertionKey, Payload>
    internal typealias Slot = RedBlackSlot<InsertionKey, Payload>

    //MARK: Stored properties

    internal private(set) var nodes: ContiguousArray<Node>

    /// The handle of the root node of the tree, or nil if the tree is empty.
    public private(set) var root: Handle?

    /// The handle of the leftmost node of the tree, or nil if the tree is empty.
    public private(set) var leftmost: Handle?

    /// The handle of the rightmost node of the tree, or nil if the tree is empty.
    public private(set) var rightmost: Handle?

    /// Initializes an empty tree.
    public init() {
        nodes = []
        root = nil
        leftmost = nil
        rightmost = nil
    }
}

//MARK: Initializers

public extension RedBlackTree {

    public init<C: CollectionType where C.Generator.Element == (InsertionKey, Payload)>(_ elements: C) {
        self.init()
        self.reserveCapacity(Int(elements.count.toIntMax()))
        for (key, payload) in elements {
            self.insert(payload, forKey: key)
        }
    }

    public mutating func reserveCapacity(minimumCapacity: Int) {
        nodes.reserveCapacity(minimumCapacity)
    }
}

//MARK: Count of nodes

public extension RedBlackTree {
    /// The number of nodes in the tree.
    public var count: Int { return nodes.count }
    public var isEmpty: Bool { return nodes.isEmpty }
}

//MARK: Looking up a handle.

public extension RedBlackTree {

    /// Returns or updates the node at `handle`.
    /// - Complexity: O(1)
    internal private(set) subscript(handle: Handle) -> Node {
        get {
            return nodes[handle.index]
        }
        set(node) {
            nodes[handle.index] = node
        }
    }

    /// Returns the node at `handle`, or nil if `handle` is nil.
    /// - Complexity: O(1)
    internal subscript(handle: Handle?) -> Node? {
        guard let handle = handle else { return nil }
        return self[handle] as Node
    }

    /// Returns the payload of the node at `handle`.
    /// - Complexity: O(1)
    public func payloadAt(handle: Handle) -> Payload {
        return self[handle].payload
    }

    /// Returns the payload of the topmost node matching `key`, if any.
    /// - Complexity: O(log(`count`))
    public func payloadOf<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Payload? {
        guard let handle = find(key) else { return nil }
        return self.payloadAt(handle)
    }

    /// Updates the payload of the node at `handle`.
    /// - Returns: The previous payload of the node.
    /// - Complexity: O(1)
    public mutating func setPayloadAt(handle: Handle, to payload: Payload) -> Payload {
        var node = self[handle]
        let old = node.payload
        node.payload = payload
        self[handle] = node
        return old
    }

    /// Returns the key of the node at `handle`.
    /// - Complexity: O(log(`count`)) if the summary is non-empty; O(1) otherwise.
    /// - Note: If you need to get the key for a range of nodes, and you have a non-empty summary, using a generator
    ///   is faster than querying the keys of each node one by one.
    /// - SeeAlso: `generate`, `generateFrom`
    public func keyAt(handle: Handle) -> InsertionKey {
        let prefix = summaryBefore(handle)
        let node = self[handle]
        return InsertionKey(summary: prefix, head: node.head)
    }

    /// Returns a typle containing the key and payload of the node at `handle`.
    /// - Complexity: O(log(`count`)) if the summary is non-empty; O(1) otherwise.
    /// - Note: If you need to get the key for a range of nodes, and you have a non-empty summary, using a generator
    ///   is faster than querying the keys of each node one by one.
    /// - SeeAlso: `generate`, `generateFrom`
    public func elementAt(handle: Handle) -> Element {
        let prefix = summaryBefore(handle)
        let node = self[handle]
        let key = InsertionKey(summary: prefix, head: node.head)
        return (key, node.payload)
    }

    /// Returns the head of the node at `handle`.
    /// - Complexity: O(1)
    public func headAt(handle: Handle) -> Head {
        return self[handle].head
    }

    /// Updates the head of the node at `handle`. 
    ///
    /// It is only supported to change the head when a the new value does
    /// not affect the order of the nodes already in the tree. New keys of nodes before or equal to `handle` must match
    /// their previous ones, but keys of nodes above `handle` may be changed -- as long as the ordering stays constant.
    ///
    /// - Note: Being able to update the head is useful when the summary is a summation, 
    ///   like in a tree implementing a concatenation of arrays, where each array's handle range in the resulting 
    ///   collection is a count of elements in all arrays before it. Here, the head of node is the count of its
    ///   payload array. When the count changes, handles after the modified array change too, but their ordering remains
    ///   the same. Calling `setHead` is ~3 times faster than just removing and re-adding the node.
    ///
    /// - Requires: The key of the old node must match the new node. `compare(key(old, prefix), new, prefix) == .Match`
    ///
    /// - Warning: Changing the head to a value that changes the ordering of items will break ordering in the tree. 
    ///   In unoptimized builds, the implementation throws a fatal error if the above expression evaluates to false, 
    ///   but this is elided from optimized builds. You should know what you're doing.
    ///
    /// - Returns: The previous head of the node.
    ///
    /// - Complexity: O(log(`count`))
    ///
    public mutating func setHeadAt(handle: Handle, to head: Head) -> Head {
        var node = self[handle]
        assert({
            let prefix = summaryBefore(handle) // This is O(log(n)) -- which is why this is not in a precondition.
            let oldKey = InsertionKey(summary: prefix, head: node.head)
            let newKey = InsertionKey(summary: prefix, head: head)
            return oldKey == newKey
            }())
        let old = node.head
        node.head = head
        self[handle] = node
        updateSummariesAtAndAbove(handle)
        return old
    }
}

//MARK: Inorder walk

extension RedBlackTree {

    public func successor(handle: Handle) -> Handle? {
        return step(handle, toward: .Right)
    }

    public func predecessor(handle: Handle) -> Handle? {
        return step(handle, toward: .Left)
    }

    public func step(handle: Handle, toward direction: RedBlackDirection) -> Handle? {
        let node = self[handle]
        if let next = node[direction] {
            return furthestUnder(next, toward: direction.opposite)
        }

        var child = handle
        var parent = node.parent
        while let p = parent {
            let n = self[p]
            if n[direction] != child { return p }
            child = p
            parent = n.parent
        }
        return nil
    }

    public func leftmostUnder(handle: Handle) -> Handle {
        return furthestUnder(handle, toward: .Left)
    }

    public func rightmostUnder(handle: Handle) -> Handle {
        return furthestUnder(handle, toward: .Right)
    }

    public func furthestToward(direction: RedBlackDirection) -> Handle? {
        return (direction == .Left ? leftmost : rightmost)
    }

    public func furthestUnder(handle: Handle, toward direction: RedBlackDirection) -> Handle {
        var handle = handle
        while let next = self[handle][direction] {
            handle = next
        }
        return handle
    }
}


//MARK: Generating all items in the tree

public struct RedBlackGenerator<Key: RedBlackInsertionKey, Payload>: GeneratorType {
    typealias Tree = RedBlackTree<Key, Payload>
    private let tree: Tree
    private var handle: Tree.Handle?
    private var summary: Tree.Summary

    public mutating func next() -> Tree.Element? {
        guard let handle = handle else { return nil }
        let node = tree[handle]
        let key = Key(summary: summary, head: node.head)
        summary += node.head
        self.handle = tree.successor(handle)
        return (key, node.payload)
    }
}

extension RedBlackTree: SequenceType {
    public typealias Generator = RedBlackGenerator<InsertionKey, Payload>

    /// Return a generator that provides an ordered list of all (key, payload) pairs that are currently in the tree.
    /// - Complexity: O(1) to get the generator; O(count) to retrieve all elements.
    public func generate() -> Generator {
        return RedBlackGenerator(tree: self, handle: leftmost, summary: Summary())
    }

    /// Return a generator that provides an ordered list of (key, payload) pairs that are at or after `handle`.
    /// - Complexity: O(1) to get the generator; O(count) to retrieve all elements.
    public func generateFrom(handle: Handle) -> Generator {
        return RedBlackGenerator(tree: self, handle: handle, summary: Summary())
    }
}

//MARK: Searching in the tree

extension RedBlackTree {
    private func find<Key: RedBlackKey where Key.Summary == Summary>(key: Key, @noescape step: (KeyMatchResult, Handle) -> KeyMatchResult) {
        var handle = self.root
        var summary = Summary()
        while let h = handle {
            let node = self[h]
            let s = summary + self[node.left]?.summary
            let k = Key(summary: s, head: node.head)
            let match: KeyMatchResult = (key < k ? .Before : key > k ? .After : .Matching)
            let next = step(match, h)
            switch next {
            case .Before:
                handle = node.left
            case .Matching:
                return
            case .After:
                summary = s + node.head
                handle = node.right
            }
        }
    }

    private func find<Key: RedBlackKey where Key.Summary == Summary>(key: Key, winding: RedBlackDirection) -> (hit: Handle?, miss: Handle?) {
        var hit: Handle? = nil
        var miss: Handle? = nil
        var handle = self.root
        var summary = Summary()
        while let h = handle {
            let node = self[h]
            let s = summary + self[node.left]?.summary
            let k = Key(summary: s, head: node.head)
            if key < k {
                if winding == .Right { miss = h }
                handle = node.left
            }
            else if key > k {
                if winding == .Left { miss = h }
                summary = s + node.head
                handle = node.right
            }
            else {
                hit = h
                handle = (winding == .Left ? node.left : node.right)
            }
        }
        return (hit, miss)
    }

    /// Finds and returns the handle of a node which matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(`count`))
    public func find<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Handle? {
        // Topmost is the best, since it terminates on the first match.
        return topmostMatching(key)
    }

    /// Finds and returns the handle of the topmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(`count`))
    public func topmostMatching<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Handle? {
        var result: Handle? = nil
        find(key) { match, handle in
            if match == .Matching { result = handle }
            return match
        }
        return result
    }

    /// Finds and returns the handle of the rightmost node that sorts before `key`, or nil if no such node exists.
    /// - Complexity: O(log(`count`))
    public func rightmostBefore<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Handle? {
        return find(key, winding: .Left).miss
    }

    /// Finds and returns the handle of the leftmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(`count`))
    public func leftmostMatching<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Handle? {
        return find(key, winding: .Left).hit
    }

    /// Finds and returns the handle of the rightmost node that matches `key`, or nil if no such node exists.
    /// - Complexity: O(log(`count`))
    public func rightmostMatching<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Handle? {
        return find(key, winding: .Right).hit
    }

    /// Finds and returns the handle of the leftmost node that sorts after `key`, or nil if no such node exists.
    /// - Complexity: O(log(`count`))
    public func leftmostAfter<Key: RedBlackKey where Key.Summary == Summary>(key: Key) -> Handle? {
        return find(key, winding: .Right).miss
    }
}

//MARK: Managing the summary data

extension RedBlackTree {
    /// Updates the summary cached at `handle`, assuming that the children have up-to-date data.
    /// - Complexity: O(1) - 3 lookups
    private mutating func updateSummaryAt(handle: Handle) -> Handle? {
        guard sizeof(Summary.self) > 0 else { return nil }
        var node = self[handle]
        node.summary = self[node.left]?.summary + node.head + self[node.right]?.summary
        self[handle] = node
        return node.parent
    }

    /// Updates the summary cached at `handle` and its ancestors, assuming that all other nodes have up-to-date data.
    /// - Complexity: O(log(`count`)) for nonempty summaries, O(1) when the summary is empty.
    private mutating func updateSummariesAtAndAbove(handle: Handle?) {
        guard sizeof(Summary.self) > 0 else { return }
        var handle: Handle? = handle
        while let h = handle {
            handle = self.updateSummaryAt(h)
        }
    }

    /// Returns the summary calculated over the sequence of all nodes below `handle`, including the top.
    /// - Complexity: O(1)
    public func summaryUnder(handle: Handle?) -> Summary {
        guard sizeof(Summary.self) > 0 else { return Summary() }
        guard let handle = handle else { return Summary() }
        return self[handle].summary
    }

    /// Returns the summary calculated over the sequence all nodes preceding `handle` in the tree.
    /// - Complexity: O(log(`count`) for nonempty summaries, O(1) when the summary is empty.
    public func summaryBefore(handle: Handle) -> Summary {
        guard sizeof(Summary.self) > 0 else { return Summary() }

        func summaryOfLeftSubtree(handle: Handle) -> Summary {
            return summaryUnder(self[handle].left)
        }

        var handle = handle
        var summary = summaryOfLeftSubtree(handle)
        while case .Toward(let direction, under: let parent) = slotOf(handle) {
            if direction == .Right {
                summary = summaryOfLeftSubtree(parent) + self[parent].head + summary
            }
            handle = parent
        }
        return summary
    }

    /// Returns the summary calculated over the sequence all nodes succeeding `handle` in the tree.
    /// - Complexity: O(log(`count`) for nonempty summaries, O(1) when the summary is empty.
    public func summaryAfter(handle: Handle) -> Summary {
        guard sizeof(Summary.self) > 0 else { return Summary() }

        func summaryOfRightSubtree(handle: Handle) -> Summary {
            return summaryUnder(self[handle].right)
        }

        var handle = handle
        var summary = summaryOfRightSubtree(handle)
        while case .Toward(let direction, under: let parent) = slotOf(handle) {
            if direction == .Left {
                summary = summary + self[parent].head + summaryOfRightSubtree(parent)
            }
            handle = parent
        }
        return summary
    }
}


//MARK: Color management

extension RedBlackTree {
    /// Only non-nil nodes may be red.
    private func isRed(handle: Handle?) -> Bool {
        guard let handle = handle else { return false }
        return self[handle].color == .Red
    }
    /// Nil nodes are considered black.
    private func isBlack(handle: Handle?) -> Bool {
        guard let handle = handle else { return true }
        return self[handle].color == .Black
    }
    /// Only non-nil nodes may be set red.
    private mutating func setRed(handle: Handle) {
        self[handle].color = .Red
    }
    /// You can set a nil node black, but it's a noop.
    private mutating func setBlack(handle: Handle?) {
        guard let handle = handle else { return }
        self[handle].color = .Black
    }
}

//MARK: Rotation

extension RedBlackTree {
    /// Rotates the subtree rooted at `handle` in the specified direction. Used when the tree implements
    /// a binary search tree.
    ///
    /// The child towards the opposite of `direction` under `handle` becomes the new root,
    /// and the previous root becomes its child towards `dir`. The rest of the children
    /// are linked up to preserve ordering in a binary search tree.
    ///
    /// - Returns: The handle of the new root of the subtree.
    internal mutating func rotate(handle: Handle, _ dir: RedBlackDirection) -> Handle {
        let x = handle
        let opp = dir.opposite
        guard let y = self[handle][opp] else { fatalError("Invalid rotation") }

        //      x                y
        //     / \              / \
        //    a   y    <-->    x   c
        //       / \          / \
        //      b   c        a   b

        var xn = self[x]
        var yn = self[y]
        let b = yn[dir]

        if let p = xn.parent { self[p].replaceChild(x, with: y) }
        yn.parent = xn.parent
        xn.parent = y
        yn[dir] = x

        xn[opp] = b
        if let b = b { self[b].parent = x }

        self[x] = xn
        self[y] = yn

        if root == x { root = y }
        // leftmost, rightmost are invariant under rotations

        self.updateSummaryAt(x)
        self.updateSummaryAt(y)
        
        return y
    }
}

//MARK: Inserting an individual element
extension RedBlackTree {
    internal func slotOf(handle: Handle) -> Slot {
        guard let parent = self[handle].parent else { return .Root }
        let pn = self[parent]
        let direction: RedBlackDirection = (handle == pn.left ? .Left : .Right)
        return .Toward(direction, under: parent)
    }

    /// - Note: This can be faster than finding the old node and inserting if not found.
    public mutating func setPayloadOf<Key: RedBlackInsertionKey where Key.Summary == Summary>(key: Key, to payload: Payload) -> (Handle, Payload?) {
        var slot: Slot = .Root
        var handle: Handle? = nil
        self.find(key) { m, h in
            switch m {
            case .Before:
                slot = .Toward(.Left, under: h)
                return .Before
            case .Matching:
                handle = h
                return .Matching
            case .After:
                slot = .Toward(.Right, under: h)
                return .After
            }
        }

        if let handle = handle {
            let old = setPayloadAt(handle, to: payload)
            return (handle, old)
        }
        else {
            let handle = insert(payload, head: key.head, into: slot)
            return (handle, nil)
        }
    }

    public mutating func insert(payload: Payload, forKey key: InsertionKey) -> Handle {
        func insertionSlotOf(key: InsertionKey) -> Slot {
            var slot: Slot = .Root
            self.find(key) { match, handle in
                switch match {
                case .Before:
                    slot = .Toward(.Left, under: handle)
                    return .Before
                case .Matching:
                    slot = .Toward(.Right, under: handle)
                    return .After
                case .After:
                    slot = .Toward(.Right, under: handle)
                    return .After
                }
            }
            return slot
        }

        let slot = insertionSlotOf(key)
        return insert(payload, head: key.head, into: slot)
    }

    public mutating func insert(payload: Payload, forKey key: InsertionKey, after predecessor: Handle?) -> Handle {
        assert(predecessor == self.rightmostBefore(key) || key == self.keyAt(predecessor!))
        return insert(payload, head: key.head, toward:.Right, from:predecessor)
    }

    public mutating func insert(payload: Payload, forKey key: InsertionKey, before successor: Handle?) -> Handle {
        assert(successor == self.leftmostAfter(key) || key == self.keyAt(successor!))
        return insert(payload, head: key.head, toward:.Left, from:successor)
    }

    private mutating func insert(payload: Payload, head: Head, toward direction: RedBlackDirection, from neighbor: Handle?) -> Handle {
        if let neighbor: Handle = neighbor {
            if let child = self[neighbor][direction] {
                let next = furthestUnder(child, toward: direction.opposite)
                return insert(payload, head: head, into: .Toward(direction.opposite, under: next))
            }
            else {
                return insert(payload, head: head, into: .Toward(direction, under: neighbor))
            }
        }
        else if let furthest = furthestToward(direction.opposite) {
            return self.insert(payload, head: head, into: .Toward(direction.opposite, under: furthest))
        }
        else {
            return self.insert(payload, head: head, into: .Root)
        }
    }

    private mutating func insert(payload: Payload, head: Head, into slot: Slot) -> Handle {
        let handle = Handle(nodes.count)
        switch slot {
        case .Root:
            assert(nodes.isEmpty)
            self.root = handle
            self.leftmost = handle
            self.rightmost = handle
            nodes.append(Node(parent: nil, head: head, payload: payload))
        case .Toward(let direction, under: let parent):
            assert(self[parent][direction] == nil)
            nodes.append(Node(parent: parent, head: head, payload: payload))
            self[parent][direction] = handle
            if leftmost == parent && direction == .Left { leftmost = handle }
            if rightmost == parent && direction == .Right { rightmost = handle }
        }

        updateSummariesAtAndAbove(handle)

        rebalanceAfterInsertion(handle)
        return handle
    }
}

//MARK: Rebalancing after an insertion
extension RedBlackTree {

    private mutating func rebalanceAfterInsertion(new: Handle) {
        var child = new
        while case .Toward(let dir, under: let parent) = slotOf(child) {
            assert(isRed(child))
            guard self[parent].color == .Red else { break }
            guard case .Toward(let pdir, under: let grandparent) = slotOf(parent) else  { fatalError("Invalid tree: root is red") }
            let popp = pdir.opposite

            if let aunt = self[grandparent][popp] where isRed(aunt) {
                //         grandparent(Black)
                //       /             \
                //     aunt(Red)     parent(Red)
                //                      |
                //                  child(Red)
                //
                setBlack(parent)
                setBlack(aunt)
                setRed(grandparent)
                child = grandparent
            }
            else if dir == popp {
                //         grandparent(Black)
                //       /             \
                //     aunt(Black)   parent(Red)
                //                    /         \
                //                  child(Red)   B
                //                    /   \
                //                   B     B
                self.rotate(parent, pdir)
                self.rotate(grandparent, popp)
                setBlack(child)
                setRed(grandparent)
                break
            }
            else {
                //         grandparent(Black)
                //       /             \
                //     aunt(Black)   parent(Red)
                //                    /      \
                //                   B    child(Red)
                //                           /    \
                //                          B      B
                self.rotate(grandparent, popp)
                setBlack(parent)
                setRed(grandparent)
                break
            }
        }
        setBlack(root)
    }
}

//MARK: Append and merge

extension RedBlackTree {

    public mutating func append(tree: RedBlackTree<InsertionKey, Payload>) {
        guard let b1 = rightmost else { self = tree; return }
        guard let c2 = tree.leftmost else { return }

        let sb = self.summaryBefore(b1)
        let sc = sb + self[b1].head
        precondition(InsertionKey(summary: sb, head: self[b1].head) <= InsertionKey(summary: sc, head: tree[c2].head))

        self.reserveCapacity(self.count + tree.count)
        var summary = sc
        var previous1 = b1
        var next2: Handle? = c2
        while let h2 = next2 {
            let node2 = tree[h2]
            previous1 = self.insert(node2.payload, head: node2.head, toward: .Right, from: previous1)
            summary += node2.head
            next2 = tree.successor(h2)
        }
    }

    public mutating func merge(tree: RedBlackTree<InsertionKey, Payload>) {
        self.reserveCapacity(self.count + tree.count)

        for (key, payload) in tree {
            self.insert(payload, forKey: key)
        }
    }
}

//MARK: Removal of nodes

extension RedBlackTree {

    public mutating func removeAll(keepCapacity keepCapacity: Bool = false) {
        nodes.removeAll(keepCapacity: keepCapacity)
        root = nil
        leftmost = nil
        rightmost = nil
    }
    
    /// Remove the node at `handle`, invalidating all existing handles.
    /// - Note: You need to discard your existing handles into the tree after you call this method.
    /// - SeeAlso: `removeAndReturnSuccessor`
    /// - Complexity: O(log(`count`))
    public mutating func remove(handle: Handle) -> Payload {
        return _remove(handle, successor: nil).1
    }

    /// Remove the node at `handle`, invalidating all existing handles.
    /// - Note: You can use the returned handle to continue operating on the tree without having to find your place again.
    /// - Returns: The handle of the node that used to follow the removed node in the original tree, or nil if 
    ///   `handle` was at the rightmost position.
    /// - Complexity: O(log(`count`))
    public mutating func removeAndReturnSuccessor(handle: Handle) -> (Handle?, Payload) {
        return _remove(handle, successor: successor(handle))
    }

    /// Remove a node, keeping track of its successor.
    /// - Returns: The handle of `successor` after the removal.
    private mutating func _remove(handle: Handle, successor: Handle?) -> (Handle?, Payload) {
        assert(handle != successor)
        // Fixme: Removing from a red-black tree is one ugly algorithm.
        let node = self[handle]
        if let _ = node.left, r = node.right {
            // We can't directly remove a node with two children, but its successor is suitable.
            // Let's remove it instead, placing its payload into handle.
            let next = successor ?? leftmostUnder(r)
            let n = self[next]
            self[handle].head = n.head
            self[handle].payload = n.payload
            // Note that the above doesn't change root, leftmost, rightmost.
            // The summary will be updated on the way up.
            let handle = _remove(next, keeping: handle)
            return (handle, node.payload)
        }
        else {
            let handle = _remove(handle, keeping: successor)
            return (handle, node.payload)
        }
    }

    /// Remove a node with at most one child, while keeping track of another handle.
    /// - Returns: The handle of `marker` after the removal.
    private mutating func _remove(handle: Handle, keeping marker: Handle?) -> Handle? {
        let node = self[handle]
        var rebalance = node.color == .Black
        let slot = slotOf(handle)
        assert(node.left == nil || node.right == nil)

        let child = node.left ?? node.right
        if let child = child {
            var childNode = self[child]
            childNode.parent = node.parent
            if node.color == .Black && childNode.color == .Red {
                childNode.color = .Black
                rebalance = false
            }
            self[child] = childNode
        }
        if let parent = node.parent {
            self[parent].replaceChild(handle, with: child)
        }

        if root == handle { root = child }
        if leftmost == handle { leftmost = child ?? node.parent }
        if rightmost == handle { rightmost = child ?? node.parent }

        updateSummariesAtAndAbove(node.parent)

        if rebalance {
            rebalanceAfterRemoval(slot)
        }

        return deleteUnlinkedHandle(handle, keeping: marker)
    }

    private mutating func deleteUnlinkedHandle(removed: Handle, keeping marker: Handle?) -> Handle? {
        let last = Handle(nodes.count - 1)
        if removed == last {
            nodes.removeLast()
            return marker
        }
        else {
            // Move the last node into handle, and remove its original place instead.
            let node = nodes.removeLast()
            self[removed] = node
            if let p = node.parent { self[p].replaceChild(last, with: removed) }
            if let l = node.left { self[l].parent = removed }
            if let r = node.right { self[r].parent = removed }

            if root == last { root = removed }
            if leftmost == last { leftmost = removed }
            if rightmost == last { rightmost = removed }

            return marker == last ? removed : marker
        }
    }

    private mutating func rebalanceAfterRemoval(slot: Slot) {
        var slot = slot
        while case .Toward(let dir, under: let parent) = slot {
            let opp = dir.opposite
            let sibling = self[parent][opp]! // there's a missing black in slot, so it definitely has a sibling tree.
            let siblingNode = self[sibling]
            if siblingNode.color == .Red { // Case (1) in [CLRS]
                // legend: label(color)[rank]
                //
                //       parent(B)[b+1]
                //      /         \
                //   slot        sibling(R)
                //   [b-1]        /      \
                //              [b]      [b]
                assert(isBlack(parent) && self[sibling].left != nil && self[sibling].right != nil)
                self.rotate(parent, dir)
                setBlack(sibling)
                setRed(parent)
                // Old sibling is now above the parent; new sibling is black.
                continue
            }
            let farNephew = siblingNode[opp]
            if let farNephew = farNephew where isRed(farNephew) { // Case (4) in [CLRS]
                //       parent[b+1]
                //       /         \
                //   slot       sibling(B)[b]
                //  [b-1]       /      \
                //           [b-1]   farNephew(R)[b-1]
                self.rotate(parent, dir)
                self[sibling].color = self[parent].color
                setBlack(farNephew)
                setBlack(parent)
                // We sacrificed nephew's red to restore the black count above slot. We're done!
                return
            }
            let closeNephew = siblingNode[dir]
            if let closeNephew = closeNephew where isRed(closeNephew) { // Case (3) in [CLRS]
                //        parent
                //       /      \
                //   slot       sibling(B)
                //  [b-1]      /          \
                //        closeNephew(R)  farNephew(B)
                //           [b-1]           [b-1]
                self.rotate(sibling, opp)
                self.rotate(parent, dir)
                self[closeNephew].color = self[parent].color
                setBlack(parent)
                // We've sacrificed the close nephew's red to restore the black count above slot. We're done!
                return
            }
            else { // Case (2) in [CLRS]
                //        parent
                //       /      \
                //   slot       sibling(B)
                //  [b-1]      /          \
                //        closeNephew(B)  farNephew(B)
                //           [b-1]           [b-1]

                // We are allowed to paint the sibling red, creating a missing black.
                setRed(sibling)

                if isRed(parent) { // We can finish this right now.
                    setBlack(parent)
                    return
                }
                // Repeat one level higher.
                slot = slotOf(parent)
            }
        }
    }
}
