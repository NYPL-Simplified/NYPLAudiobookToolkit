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
