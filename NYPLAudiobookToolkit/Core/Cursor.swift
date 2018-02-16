//
//  Cursor.swift
//  NYPLAudiobookToolkit
//
//  Created by Dean Silfen on 2/15/18.
//  Copyright © 2018 Dean Silfen. All rights reserved.
//

import UIKit

class Cursor<T> {
    var currentElement: T {
        return self.data[self.index]
    }
    
    func prev() -> Cursor<T>? {
        return Cursor(data: self.data, index: self.index - 1)
    }
    
    func next() -> Cursor<T>? {
        return Cursor(data: self.data, index: self.index + 1)
    }
    
    func cursor(at: (_ element: T) -> Bool) -> Cursor<T>? {
        var cursor: Cursor<T>?
        for (i, element) in self.data.enumerated() {
            if at(element) {
                cursor = Cursor(data: self.data, index: i)
                break
            }
        }
        return cursor
    }

    let data: [T]
    let index: Int
    init?(data: [T], index: Int) {
        guard index >= data.startIndex else {
            return nil
        }
        guard index < data.count else {
            return nil
        }
        self.data = data
        self.index = index
    }
}
