//

import CoreData

@objc(CoreDataFeedImage)
internal class CoreDataFeedImage: NSManagedObject {
    
    @NSManaged var id: UUID
    @NSManaged var location: String?
    @NSManaged var managedDescription: String?
    @NSManaged var url: URL
}
