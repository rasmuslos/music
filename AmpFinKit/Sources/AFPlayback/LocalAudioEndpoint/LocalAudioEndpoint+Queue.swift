//
//  File.swift
//
//
//  Created by Rasmus Krämer on 19.03.24.
//

import Foundation
import AVKit
import AFFoundation
import AFNetwork

internal extension LocalAudioEndpoint {
    func advance(advanceAudioPlayer: Bool) {
        if let nowPlaying {
            history.append(nowPlaying)
            
            if avPlayerQueue.first == nowPlaying.id {
                avPlayerQueue.removeFirst()
            }
        }
        
        print(nowPlaying?.name)
        
        let queueWasEmpty: Bool
        
        if queue.isEmpty {
            if infiniteQueue!.isEmpty {   
                queue = history
                history = []
                
                queueWasEmpty = true
            } else {
                queueWasEmpty = false
                queue.append(infiniteQueue!.removeLast())
            }
        } else {
            queueWasEmpty = false
        }
        
        guard !queue.isEmpty else {
            stopPlayback()
            return
        }
        
        print(queue.map { $0.name })
        
        nowPlaying = queue.first
        
        audioPlayer.advanceToNextItem()
        playing = !queueWasEmpty || repeatMode != .none
        
        avPlayerQueue.removeFirst()
        queue.removeFirst()
        
        if !playing {
            audioPlayer.seek(to: CMTime(seconds: 0, preferredTimescale: 1000))
        }
    }
    
    func checkAndUpdateInfiniteQueue() {
        guard infiniteQueue!.count < 6, repeatMode == .infinite else {
            return
        }
        
        guard let last = queue.last ?? nowPlaying else {
            return
        }
        
        Task {
            guard let tracks = try? await JellyfinClient.shared.tracks(instantMixBaseId: last.id, limit: 28) else {
                return
            }
            
            let historySuffix = history.suffix(20)
            infiniteQueue!.append(contentsOf: tracks.filter { !historySuffix.contains($0) && !queue.contains($0) })
        }
    }
}

internal extension LocalAudioEndpoint {
    func advance() {
        advance(advanceAudioPlayer: true)
    }
    func rewind() {
        if currentTime > 5 || history.count < 1 {
            currentTime = 0
            return
        }
        
        let previous = history.removeLast()
        
        if let nowPlaying = nowPlaying {
            queue.insert(nowPlaying, at: 0)
        }
        
        queue.insert(previous, at: 0)
        advance()
        
        history.removeLast()
    }
    func skip(to index: Int) {
        if queue.count > index {
            history.append(contentsOf: queue[0..<index])
            queue.remove(atOffsets: IndexSet(0..<index))
            
            advance()
            
            let previous = history.removeLast()
            history.insert(previous, at: history.count - index)
        } else {
            let infiniteIndex = index - queue.count
            
            guard infiniteQueue!.count > infiniteIndex else {
                return
            }
            
            queue.append(infiniteQueue!.remove(at: infiniteIndex))
            
            advance()
            
            history.append(contentsOf: queue)
            history.append(contentsOf: infiniteQueue![0..<infiniteIndex])
            
            queue = []
            infiniteQueue!.remove(atOffsets: IndexSet(0..<infiniteIndex))
        }
    }
    
    func queue(_ track: Track, after index: Int, updateUnalteredQueue: Bool = true) {
        if updateUnalteredQueue {
            unalteredQueue.insert(track, at: index)
        }
        
        queue.insert(track, at: index)
    }
    func queue(_ tracks: [Track], after index: Int) {
        for (i, track) in tracks.enumerated() {
            queue(track, after: index + i)
        }
    }
    
    func remove(at index: Int) -> Track? {
        if queue.count < index + 1 {
            return nil
        }
        
        let track = queue.remove(at: index)
        
        if let index = unalteredQueue.firstIndex(where: { $0.id == track.id }) {
            unalteredQueue.remove(at: index)
        }
        
        return track
    }
    func removePlayed(at index: Int) {
        history.remove(at: index)
    }
    
    func move(from index: Int, to destination: Int) {
        guard let track = remove(at: index) else {
            return
        }
        
        if index < destination {
            queue(track, after: destination + 1)
        } else {
            queue(track, after: destination)
        }
    }
    
    func restorePlayed(upTo index: Int) {
        let amount = history.count - index
        for track in history.suffix(amount).reversed() {
            queue(track, after: 0, updateUnalteredQueue: false)
        }
        
        history.removeLast(amount)
        
        if let nowPlaying = nowPlaying {
            queue(nowPlaying, after: queue.count)
        }
        
        advance()
        history.removeLast()
    }
}
