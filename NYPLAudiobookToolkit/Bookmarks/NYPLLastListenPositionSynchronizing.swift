//
//  NYPLLastListenPositionSynchronizing.swift
//  
//
//  Created by Ernest Fan on 2022-11-29.
//

import Foundation

@objc
public protocol NYPLLastListenPositionSynchronizing {
  func getLastListenPosition(completion: @escaping (_ localPosition: NYPLAudiobookBookmark?, _ serverPosition: NYPLAudiobookBookmark?) -> ())
  func updateLastListenPositionInMemory(_ location: ChapterLocation)
  func syncLastListenPositionToServer()
}
