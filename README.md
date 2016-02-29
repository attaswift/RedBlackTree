# Red-Black Trees in Swift

[![Swift 2.1](https://img.shields.io/badge/Swift-2.1-blue.svg)](https://developer.apple.com/swift/)
[![License](https://img.shields.io/badge/licence-MIT-blue.svg)](https://github.com/lorentey/RedBlackTree/blob/master/LICENCE.md)

[![Build Status](https://travis-ci.org/lorentey/RedBlackTree.svg?branch=master)](https://travis-ci.org/lorentey/RedBlackTree)
[![Code Coverage](https://codecov.io/github/lorentey/RedBlackTree/coverage.svg?branch=master)](https://codecov.io/github/lorentey/RedBlackTree?branch=master)

This project provides an implementation of [red-black trees][wiki] in pure Swift as structs with value semantics.
The nodes are stored in bulk inside a single flat `Array`, with array indexes serving as pointers.

[wiki]: https://en.wikipedia.org/wiki/Red–black_tree

`RedBlackTree` supports value-based lookup, positional lookup, or a combination of both, depending on how 
you configure its key type, `RedBlackKey`. For example, you can create a single red-black tree that supports 
lookup  based on either a key stored in each element, the position of the element, or a weighted position.

I created this package to make a set of ordered collection types in Swift. 
However, benchmarking showed that the performance of red-black trees isn't great, 
and I chose to base my collection types on b-trees instead.
If you're in need of a fast ordered collection type, be sure
check out my [BTree](https://github.com/lorentey/BTree) project before settling on red-black trees.
