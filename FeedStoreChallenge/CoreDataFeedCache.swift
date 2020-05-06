//

import CoreData

@objc(CoreDataFeedCache)
internal class CoreDataFeedCache: NSManagedObject {
    
    @NSManaged var timestamp: Date
    @NSManaged var feed: NSOrderedSet
}
