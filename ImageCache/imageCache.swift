//
//  cache.swift
//  ImageCache
//
//  Created by Alix on 26/06/2019.
//


// TODO(a.mougenot, 1-JUL-2019): Disk storage API

import UIKit

/// Image Cache is an asynchronous image loader that can load images in the background, while keeping a cache of the most recently used.
/// It has a persistance layer that keeps images in memory for ImageCache.imageTimeToLive seconds.
/// Memory warnings will trigger all instances to call self.removeAll().
/// - Note: This class is meant to be used as a singleton. But you can instanciate many ImageCaches for in-memory use as you want.
public class ImageCache {

    // MARK: - Internal State

    // concurrent queue used to protect the cache from concurrent writes.
    internal var queue: DispatchQueue

    // the state for every image to load
    internal var storage:[URL:ImageCacheEntry]

    // MARK: - Public Tweaking variables

    /// This variable dicates how long images are considred valid for this instance of ImageCache.
    /// You can change the value if you need to fine control how long images are retained for this instance.
    /// Note that this is per instance of the ImageCache. You can create short lived and long lived caches if you need to have different lifespans.
    /// You cannot set this to a value smaller than 1.0
    public var imageTimeToLive: TimeInterval = 10 * 60.0 {
        didSet(oldvalue) {
            // we prevent users from setting absurd values
            if self.imageTimeToLive < 1.0 {
                self.imageTimeToLive = oldvalue
            }

            // if smaller we may need to evict entries
            guard oldvalue > self.imageTimeToLive else { return }
            self.queue.async { self.cacheRotation() }
        }
    }

    /// This variable dictates how many images are kept in memory. When max is reached, 10% of the max will be evicted form memory.
    /// You cannot set this value smaller than 1.
    public var imageMemoryMaxCount: Int = 100 {
        didSet(oldvalue) {
            // we prevent users from setting absurd values
            if self.imageMemoryMaxCount < 1 {
                self.imageMemoryMaxCount = oldvalue
            }

            // if smaller we may need to evict entries
            guard oldvalue > self.imageMemoryMaxCount else { return }
            self.queue.async { self.cacheRotation() }
        }
    }


    // MARK: - Init Code

    /// Singleton to access a default shared cache instance accross your App. Note that you can create instances of the cache when needed.
    public static let shared = ImageCache()

    /// Creates a dedicated ImageCache. Each instance will run opperations in a dedicated queue and clear all content upon the system emiting a MemoryWarningNotification
    public init () {
        self.queue = DispatchQueue(label: "ImageCacheAccessQueue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        self.storage = [URL:ImageCacheEntry]()
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] (_:Notification) in
            self?.removeAll()
        }
        // Note(a.mougenot, 28-Jun-2019): Looks like the block passed to notification center itself will leak.
        //                                It's not that bad because self is a weak reference, and this is intended to be a Singleton.
    }

    // MARK: - API

    /// This function is used to asynchornously fetch an image given its URL.
    /// When the image is ready the callback is triggered in the main queue asynchrounously.
    /// If anything wrong happens while fetching the image, the image passed to the callback will be nil.
    /// - important: the callback is always executed asynchrnously on the main queue. It is executed at best once.
    /// - parameter callback: This callback is called upon the image beeing downloaded or found in the memory cache.
    ///            Multiple call to this method fot the same URL will stack the callbacks, they will all be called in the order of the method calls.
    ///            The callback is not called when the request is cancelled or the cache cleared by calling [removeAll](x-source-tag://removeAll).
    ///            The callback is deleted after call to avoid leaking.
    /// - parameter url: The URL for the image you want to fetch.
    public func fetch(_ url:URL, callback:((URL, UIImage?) -> ())?) {
        self.queue.async {
            // A: we have a valid image in memory
            if let entry = self.storage[url], let image = entry.image, entry.url == url, Date().timeIntervalSince(entry.lastUsed) < self.imageTimeToLive {
                DispatchQueue.main.async { callback?(url, image) }
                return
            }

            // B: image is already beeing loaded, we stack the callbacks
            if let entry = self.storage[url], entry.loading {
                var newEntry = entry

                if let newCallback = callback { // if the user passed a callback, we stack it.
                    let oldCallback = entry.callback
                    let magicCallback = { (a:URL, b:UIImage?) -> Void in
                        oldCallback?(a,b)
                        newCallback(a,b)
                    }
                    newEntry.callback = magicCallback
                }

                newEntry.lastUsed = Date()
                self.storage[url] =  newEntry

                return // Nothing more to do, image is beeing loaded
            }

            // C: here we don't have a valid entry (maybe nil), let's create a fresh one.
            self.storage[url] = ImageCacheEntry(lastUsed: Date(), downloadDate: Date(), url: url, image: nil, loading: true, cancel: false, callback: callback)
            self.cacheRotation() // we just added an entry, maybe cache needs to evict some entries.

            DispatchQueue.global().async {
                // Note(a.mougenot, 26-JUN-2019): We could improve this by using a background download task from the system instead of this.
                // Note(a.mougenot, 28-JUN-2019): Using Data(contentsOf:) to load does not return an error and is not cancelable, maybe consider something more complex.
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    self.imageArrived(url: url, image: image)
                } else {
                    self.imageArrived(url: url, image: nil)
                }
            }
        }
    }


    /// this function asynchronously deletes the image corresponding to the given URL.
    /// If a download is running for that image, the callback will not be called and the image will not be stored.
    public func remove(_ url: URL) {
        self.queue.async() {
            guard var state = self.storage[url] else { return }

            if state.loading {
                state.cancel = true // this will delete the entry when the image is downloaded
                state.image = nil
                self.storage[url] = state
            } else {
                self.storage.removeValue(forKey: url)
            }
        }
    }

    /// Synchronous access to the image cache. This does not load the image but can be used if you need a synchonous access to loaded images.
    /// - parameter url: The URL used to load the image.
    /// - returns: The image if found, nil if the image is not already loaded.
    public func peek(_ url: URL) -> UIImage? {
        var result:UIImage? = nil
        self.queue.sync {
            guard var state = self.storage[url] else { return }

            result = state.image

            state.lastUsed = Date()
            self.storage[url] = state
        }
        return result
    }

    /// Synchronous access to the image cache. This will return true iff the loading of the image failed for any reason.
    /// - parameter url: The URL used to load the image.
    /// - returns: true iff an error occured while fetching the image, for any reason.
    public func failedToFetch(_ url: URL) -> Bool {
        var result:Bool = false
        self.queue.sync {
            guard let state = self.storage[url] else { return }
            result = state.image == nil && !state.loading
        }
        return result
    }

    /// Synchronous access to the image cache. This will return true iff the instance it loading the image.
    /// - parameter url: The URL used to load the image.
    /// - returns: true iff the instance it loading the image.
    public func fetching(_ url: URL) -> Bool {
        var result:Bool = false
        self.queue.sync {
            guard let state = self.storage[url] else { return }
            result = state.image == nil && state.loading
        }
        return result
    }


    /// synchronously frees the memory used by images in cache, ongoing downloads will be cancelled.
    /// Tag:removeAll
    public func removeAll() {
        self.queue.sync() {
            self.storage.removeAll() // Note: this will also remove the callbacks that are stored in the state.
        }
    }

    // MARK: - Internal Code

    // handles insersion of images into the cache and callback logic
    internal func imageArrived(url:URL, image:UIImage?) {
        self.queue.async {
            guard var state = self.storage[url] else {
                return // can happen if you free the cache while downloading
            }

            if state.cancel {
                self.storage.removeValue(forKey: url)
                return
            }

            let definedCallback = state.callback

            state.lastUsed = Date()
            state.downloadDate = Date()
            state.image = image
            state.callback = nil
            state.loading = false

            self.storage[url] = state

            if let callback = definedCallback {
                DispatchQueue.main.async {
                    callback(url, image)
                }
            }
        }
    }


    // cleans cache to free some space
    // ⚠️ call from within self.queue queue, it accesses shared state to run
    internal func cacheRotation() {
        let now = Date()
        for (key, entry) in self.storage {
            if now.timeIntervalSince(entry.downloadDate) > self.imageTimeToLive {
                self.storage.removeValue(forKey: key) // this is safe: remember that dicts are values, iteration is done on a copy.
            }
        }

        if self.storage.count < self.imageMemoryMaxCount { return }

        // we will evict 10% of the stored images, regardless of size
        let sortedEntries = self.storage.sorted { $0.value.lastUsed < $1.value.lastUsed } // the smaller the date the older they are
        let retainSize = Int(Double(self.imageMemoryMaxCount) * 0.9) + 1
        for (key, _) in sortedEntries.prefix(retainSize) {
            self.evictFromMemory(key)
        }

    }


    // this function evicts the entry corresponding to the given URL, possibly moving it to disk
    // ⚠️ call from within self.queue queue, it accesses shared state to run
    internal func evictFromMemory(_ entryKey: URL) {
        guard let removedEntry = self.storage.removeValue(forKey: entryKey) else {return}

        if removedEntry.image != nil {
            // TODO(a.mougenot, 1-July-2019): move to disk
        }

    }

}


/// This represent the loading state of a given image
internal struct ImageCacheEntry {
    /// last time the client wanted the image, used to evict the last recently used.
    var lastUsed: Date

    /// used to delete images that are older than the time to live.
    var downloadDate: Date

    /// The url is copied here so that we can rely on something else to index the images in the future.
    var url: URL

    /// the image is stored in the state
    var image: UIImage?

    /// loading is set to true when we start to fetch an image
    var loading: Bool

    /// cancel is set to true when download task should be ignored and image deleted
    var cancel: Bool

    /// a callback for when we finish to fetch the image, needs to be freed after call to avoid retainning the world.
    var callback: ((URL, UIImage?) -> ())?
}

