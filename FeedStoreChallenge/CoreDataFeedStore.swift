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
    
    private func fetchCurrentCache(from context: NSManagedObjectContext) -> CoreDataFeedCache? {
        let request: NSFetchRequest<CoreDataFeedCache> = CoreDataFeedCache.fetchRequest()
        return try? context.fetch(request).first
    }
    
    private func markCurrentCacheAsDeleted(from context: NSManagedObjectContext) {
        if let cache = fetchCurrentCache(from: context) {
            context.delete(cache)
        }
    }
}

extension CoreDataFeedStore {
    
    public func retrieve(completion: @escaping RetrievalCompletion) {
        if let cache = self.fetchCurrentCache(from: context), let cached = self.map(cache) {
            completion(.found(feed: cached.feed, timestamp: cached.timestamp))
        } else {
            completion(.empty)
        }
    }
    
    private func map(_ cache: CoreDataFeedCache) -> (feed: [LocalFeedImage], timestamp: Date)? {
        if let feedSet = cache.feed, feedSet.count > 0 {
            let feed = feedSet.compactMap({ $0 as? CoreDataFeedImage }).map { $0.toLocal() }
            return (feed: feed, timestamp: cache.timestamp!)
        }
        
        return nil
    }
}

extension CoreDataFeedStore {

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
    
    private func createCache(with feed: [LocalFeedImage], timestamp: Date, into context: NSManagedObjectContext) {
        let coreDataFeed: [CoreDataFeedImage] = feed.map { map($0, with: context) }
        
        let cache = CoreDataFeedCache(context: context)
        cache.addToFeed(NSOrderedSet(array: coreDataFeed))
        cache.timestamp = timestamp
    }
    
    private func map(_ feedImage: LocalFeedImage, with context: NSManagedObjectContext) -> CoreDataFeedImage {
        let coreDataFeedImage = CoreDataFeedImage(context: context)
        coreDataFeedImage.id = feedImage.id
        coreDataFeedImage.managedDescription = feedImage.description
        coreDataFeedImage.location = feedImage.location
        coreDataFeedImage.url = feedImage.url
        return coreDataFeedImage
    }
}
 
extension CoreDataFeedStore {

    public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        backgroundContext.performAndWait {
            self.markCurrentCacheAsDeleted(from: backgroundContext)
            try? backgroundContext.save()
            completion(nil)
        }
    }
}

private extension CoreDataFeedImage {
    
    func toLocal() -> LocalFeedImage {
        LocalFeedImage(id: id!, description: managedDescription, location: location, url: url!)
    }
}
