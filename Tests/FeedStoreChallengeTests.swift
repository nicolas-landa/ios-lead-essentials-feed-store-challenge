//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

import XCTest
import CoreData
import FeedStoreChallenge

class CoreDataFeedStore: FeedStore {
    
    private var context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func retrieve(completion: @escaping RetrievalCompletion) {
        if let cache = fetchCache(from: context), let cached = map(cache) {
            completion(.found(feed: cached.feed, timestamp: cached.timestamp))
        } else {
            completion(.empty)
        }
    }
    
    func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        markCurrentCacheAsDeleted(from: context)
        createCache(with: feed, timestamp: timestamp, into: context)
        
        do {
            try context.save()
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        markCurrentCacheAsDeleted(from: context)
        try? context.save()
        completion(nil)
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

class FeedStoreChallengeTests: XCTestCase, FeedStoreSpecs {
	
//
//   We recommend you to implement one test at a time.
//   Uncomment the test implementations one by one.
// 	 Follow the process: Make the test pass, commit, and move to the next one.
//
    
    override func setUp() {
        super.setUp()
        
        loadTestSpecificPersistentContainer()
    }

	func test_retrieve_deliversEmptyOnEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveDeliversEmptyOnEmptyCache(on: sut)
	}

	func test_retrieve_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveHasNoSideEffectsOnEmptyCache(on: sut)
	}

	func test_retrieve_deliversFoundValuesOnNonEmptyCache() {
		let sut = makeSUT()
        
		assertThatRetrieveDeliversFoundValuesOnNonEmptyCache(on: sut)
	}

	func test_retrieve_hasNoSideEffectsOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatRetrieveHasNoSideEffectsOnNonEmptyCache(on: sut)
	}

	func test_insert_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		assertThatInsertDeliversNoErrorOnEmptyCache(on: sut)
	}

	func test_insert_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatInsertDeliversNoErrorOnNonEmptyCache(on: sut)
	}

	func test_insert_overridesPreviouslyInsertedCacheValues() {
		let sut = makeSUT()

		assertThatInsertOverridesPreviouslyInsertedCacheValues(on: sut)
	}

	func test_delete_deliversNoErrorOnEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteDeliversNoErrorOnEmptyCache(on: sut)
	}

	func test_delete_hasNoSideEffectsOnEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteHasNoSideEffectsOnEmptyCache(on: sut)
	}

	func test_delete_deliversNoErrorOnNonEmptyCache() {
		let sut = makeSUT()

		assertThatDeleteDeliversNoErrorOnNonEmptyCache(on: sut)
	}

	func test_delete_emptiesPreviouslyInsertedCache() {
		let sut = makeSUT()

		assertThatDeleteEmptiesPreviouslyInsertedCache(on: sut)
	}

	func test_storeSideEffects_runSerially() {
//		let sut = makeSUT()
//
//		assertThatSideEffectsRunSerially(on: sut)
	}
	
	// - MARK: Helpers
    
    private var container: NSPersistentContainer!
	
	private func makeSUT() -> FeedStore {
        let context = container.viewContext
        let coreDataFeedStore = CoreDataFeedStore(context: context)
        return coreDataFeedStore
	}
    
    private func loadTestSpecificPersistentContainer() {
        let bundle: Bundle = Bundle(identifier: "com.essentialdeveloper.FeedStoreChallenge")!
        let modelPath = bundle.path(forResource: "FeedStore", ofType: "momd")!
        let modelURL = URL(fileURLWithPath: modelPath)
        let managedModel = NSManagedObjectModel(contentsOf: modelURL)!
        
        let inMemoryDescription = NSPersistentStoreDescription()
        inMemoryDescription.type = NSInMemoryStoreType
        inMemoryDescription.shouldAddStoreAsynchronously = false
        
        container = NSPersistentContainer(name: "FeedStore", managedObjectModel: managedModel)
        container.persistentStoreDescriptions = [inMemoryDescription]
        
        let exp = expectation(description: "Wait for CoreData load completion")
        container.loadPersistentStores { (description, error) in
            if let error = error {
                XCTFail("Unexpected error \(error) when loading NSPersistentContainer")
            }
            
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
}

//
// Uncomment the following tests if your implementation has failable operations.
// Otherwise, delete the commented out code!
//

//extension FeedStoreChallengeTests: FailableRetrieveFeedStoreSpecs {
//
//	func test_retrieve_deliversFailureOnRetrievalError() {
////		let sut = makeSUT()
////
////		assertThatRetrieveDeliversFailureOnRetrievalError(on: sut)
//	}
//
//	func test_retrieve_hasNoSideEffectsOnFailure() {
////		let sut = makeSUT()
////
////		assertThatRetrieveHasNoSideEffectsOnFailure(on: sut)
//	}
//
//}

//extension FeedStoreChallengeTests: FailableInsertFeedStoreSpecs {
//
//	func test_insert_deliversErrorOnInsertionError() {
////		let sut = makeSUT()
////
////		assertThatInsertDeliversErrorOnInsertionError(on: sut)
//	}
//
//	func test_insert_hasNoSideEffectsOnInsertionError() {
////		let sut = makeSUT()
////
////		assertThatInsertHasNoSideEffectsOnInsertionError(on: sut)
//	}
//
//}

//extension FeedStoreChallengeTests: FailableDeleteFeedStoreSpecs {
//
//	func test_delete_deliversErrorOnDeletionError() {
////		let sut = makeSUT()
////
////		assertThatDeleteDeliversErrorOnDeletionError(on: sut)
//	}
//
//	func test_delete_hasNoSideEffectsOnDeletionError() {
////		let sut = makeSUT()
////
////		assertThatDeleteHasNoSideEffectsOnDeletionError(on: sut)
//	}
//
//}
