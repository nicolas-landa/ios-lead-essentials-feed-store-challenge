//

import CoreData

public class CoreDataFeedStore: FeedStore {
    
    private var context: NSManagedObjectContext
    private lazy var backgroundContext: NSManagedObjectContext = {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        return backgroundContext
    }()
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    public func retrieve(completion: @escaping RetrievalCompletion) {
        if let cache = self.fetchCache(from: context), let cached = self.map(cache) {
            completion(.found(feed: cached.feed, timestamp: cached.timestamp))
        } else {
            completion(.empty)
        }
    }
    
    public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        backgroundContext.performAndWait {
            self.markCurrentCacheAsDeleted(from: backgroundContext)
            self.createCache(with: feed, timestamp: timestamp, into: backgroundContext)
            
            do {
                try backgroundContext.save()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        backgroundContext.performAndWait {
            self.markCurrentCacheAsDeleted(from: backgroundContext)
            try? backgroundContext.save()
            completion(nil)
        }
    }
    
    private func fetchCache(from context: NSManagedObjectContext) -> CoreDataFeedCache? {
        let request: NSFetchRequest<CoreDataFeedCache> = CoreDataFeedCache.fetchRequest()
        return try? context.fetch(request).first
    }
    
    private func markCurrentCacheAsDeleted(from context: NSManagedObjectContext) {
        if let cache = fetchCache(from: context) {
            context.delete(cache)
        }
    }
    
    private func createCache(with feed: [LocalFeedImage], timestamp: Date, into context: NSManagedObjectContext) {
        let coreDataFeed: [CoreDataFeedImage] = feed.enumerated().map { map($1, withPosition: $0, with: context) }
        
        let cache = CoreDataFeedCache(context: context)
        cache.addToFeed(NSSet(array: coreDataFeed))
        cache.timestamp = timestamp
    }
    
    private func map(_ cache: CoreDataFeedCache) -> (feed: [LocalFeedImage], timestamp: Date)? {
        if let feedSet = cache.feed, feedSet.count > 0 {
            let feed = feedSet.sortedArray(using: [NSSortDescriptor(key: "position", ascending: true)]).compactMap({ $0 as? CoreDataFeedImage })
            return (feed: feed.map { $0.toLocal() }, timestamp: cache.timestamp!)
        }
        
        return nil
    }
    
    private func map(_ feedImage: LocalFeedImage, withPosition index: Int, with context: NSManagedObjectContext) -> CoreDataFeedImage {
        let coreDataFeedImage = CoreDataFeedImage(context: context)
        coreDataFeedImage.id = feedImage.id
        coreDataFeedImage.managedDescription = feedImage.description
        coreDataFeedImage.location = feedImage.location
        coreDataFeedImage.url = feedImage.url
        coreDataFeedImage.position = Int64(index)
        return coreDataFeedImage
    }
}

private extension CoreDataFeedImage {
    
    func toLocal() -> LocalFeedImage {
        LocalFeedImage(id: id!, description: managedDescription, location: location, url: url!)
    }
}
