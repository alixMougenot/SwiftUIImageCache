//
//  cache.swift
//  ImageCache
//
//  Created by Alix on 26/06/2019.
//


// TODO: Disk storage API

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

    /// Tweak this if you need to retain images more/less long in memory
    public var imageTimeToLive: TimeInterval = 10 * 60.0

    /// Tweak this to retain more or less images in the memory cache. Note that if max is reached, 10% of max space will be deleted.
    public var imageMaxCount: Int = 100

    // MARK: - Init Code

    /// Singleton to access a Default Shared cache instance accross your App. Note that you can create other instances of the cache if needed.
    public static let shared = ImageCache()

    /// Creates a dedicated ImageCache. Each instance will run opperations in a dedicated queue and clear all content upon the system emiting a MemoryWarningNotification
    public init () {
        self.queue = DispatchQueue(label: "ImageCacheAccessQueue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        self.storage = [URL:ImageCacheEntry]()
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] (_:Notification) in
            self?.removeAll()
        }
        // Note(a.mougenot, 28-Jun-2019): Looks like the block itself will leak.
        //                                It's not that bad because self itself is a weak reference, and this intended to be a Singleton.
    }

    // MARK: - API

    /// This function is used to fetch an image given its URL.
    /// When the image is ready the callback is triggered in the main queue asynchrounously.
    /// If anything wrong happens while fetching the image, the image will be nil.
    /// - Warning: the callback is always executed asynchrnously on the main queue. It is executed at best once.
    ///            The callback is not called when the request is cancelled or the cache cleared.
    ///            The callback is deleted after call to avoid leaking.
    public func fetch(url:URL, callback:((URL, UIImage?) -> ())?) {
        self.queue.async {
            // A: we have the image
            if let entry = self.storage[url], let image = entry.image, entry.url == url {
                DispatchQueue.main.async { callback?(url, image) }
                return
            }

            // B: image is already beeing loaded
            if let entry = self.storage[url], entry.loading {
                let oldCallback = entry.callback
                let magicCallback = { (a:URL, b:UIImage?) -> Void in
                    oldCallback?(a,b)
                    callback?(a,b)
                }

                var newEntry = entry
                newEntry.callback = magicCallback
                self.storage[url] =  newEntry

                return // Nothing more to do, image is beeing loaded
            }

            // C: here either we don't have a valid entry, let's create one.
            self.storage[url] = ImageCacheEntry(lastUsed: Date(), url: url, image: nil, loading: true, cancel: false, callback: callback)
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
    public func remove(url: URL) {
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

    /// Synchronous access to the image cache. This does not load the image but can be used if you need a synchonous access.
    /// Calling this method extends the lifespan of the returned image in the cache.
    /// - parameter url: The URL used to load the image.
    /// - returns: The image if found, nil if the image is not already loaded.
    public func peek(url: URL) -> UIImage? {
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
    public func failed(url: URL) -> Bool {
        var result:Bool = false
        self.queue.sync {
            guard let state = self.storage[url] else { return }
            result = state.image == nil && !state.loading
        }
        return result
    }


    /// synchronously frees the memory used by images in cache, ongoing downloads will be cancelled.
    public func removeAll() {
        self.queue.sync() {
            self.storage.removeAll() // Note: this will also removes the callbacks that are stored in the state.
        }
    }

    // MARK: - Private


    // cleans cache to free some space
    internal func cacheRotation() {

    }

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
}


/// This represent the loading state of a given image
internal struct ImageCacheEntry {
    /// last time the client wanted the image
    var lastUsed: Date

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

