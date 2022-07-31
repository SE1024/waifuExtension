//
//  MainModel.swift
//  waifuExtension
//
//  Created by Vaida on 6/22/22.
//

import SwiftUI
import Support



public final class MainModel: ObservableObject {
    
    @Published public var items: [WorkItem] = []
    
    @MainActor
    public func append(from sources: [FinderItem]) async {
        let sources = [FinderItem](from: sources).concurrentCompactMap { item -> WorkItem? in
            return autoreleasepool {
                guard !items.contains(item) else { return nil }
                if item.image != nil {
                    return WorkItem(at: item, type: .image)
                } else if item.avAsset?.videoTrack != nil {
                    return WorkItem(at: item, type: .video)
                } else {
                    return nil
                }
            }
        }
        items.append(contentsOf: sources)
    }
    
    public init(items: [WorkItem] = []) {
        self.items = items
    }
    
    @MainActor
    public func reset() {
        self.items = []
        DispatchQueue.global().async {
            FinderItem.generatedFolder.clear()
        }
    }
    
}


