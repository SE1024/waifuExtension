//
//  WorkItemDocument.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import SwiftUI
import Support
import UniformTypeIdentifiers

@dynamicMemberLookup public class WorkItemDocument: Document {
    
    public static var coderFormat: Data.CodingFormat = .json()
    
    public typealias Snapshot = [WorkItem]
    
    @Published public var container: Snapshot
    
    /// The types this class can read, for writing, see `writableContentTypes`.
    public static var readableContentTypes: [UTType] = []
    
    public static var writableContentTypes: [UTType] = [.folder]
    
    public required init(container: Snapshot) {
        self.container = container
    }
    
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Snapshot, Subject>) -> Subject {
        get { container[keyPath: keyPath] }
        set { container[keyPath: keyPath] = newValue }
    }
    
    public subscript<Subject>(dynamicMember keyPath: KeyPath<Snapshot, Subject>) -> Subject {
        container[keyPath: keyPath]
    }
    
    public required init(configuration: ReadConfiguration) throws {
        fatalError()
    }
    
    public func snapshot(contentType: UTType) throws -> [WorkItem] {
        container
    }
    
    public func fileWrapper(snapshot: [WorkItem], configuration: WriteConfiguration) throws -> FileWrapper {
        var wrappers: [String: FileWrapper] = [:]
        for item in snapshot {
            wrappers[item.name] = try FileWrapper(url: item.url)
        }
        return FileWrapper(directoryWithFileWrappers: wrappers)
    }
    
}
