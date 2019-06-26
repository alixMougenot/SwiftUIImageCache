//
//  cache.swift
//  ImageCache
//
//  Created by Alix on 26/06/2019.
//


// TODO: Disk storage API

import UIKit

/// Image Cache is an asynchronous cache that can load images in the background.
/// It has a persistance layer that can persist images in memory for ImageCache.imageTimeToLive seconds.
/// Memory warnings will clear the cache.
/// - Note: This class is meant to be used as a singleton. But you can instanciate many ImageCaches for in-memory use as you want.
class ImageCache {

    // MARK: - Internal State

    // concurrent queue used to protect the cache from concurrent writes.
    private var queue: DispatchQueue

    // the state for every image to load
    private var storage:[URL:ImageCacheEntry]

    // MARK: Tweaking variables

    /// Tweak this if you need to retain images more/less long in memory
    public var imageTimeToLive: TimeInterval = 10 * 60.0

    /// Tweak this to retain more or less images in the memory cache. Note that if max is reached, 10% of max space will be deleted.
    public var imageMaxCount: Int = 100


    init () {
        self.queue = DispatchQueue(label: "ImageCacheAccessQueue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        self.storage = [URL:ImageCacheEntry]()
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
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    self.imageArrived(url: url, image:image)
                }

                // Note(a.mougenot, 26-JUN-2019): We could improve this by using a background download task from the system instead of this.
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


    /// synchronously frees the memory used by images in cache, ongoing downloads will be cancelled.
    public func removeAll() {
        self.queue.sync() {
            self.storage.removeAll() // Note: this will also removes the callbacks that are stored in the state.
        }
    }

    // MARK: - Private

    // TODO: memory warning

    // cleans cache to free some space
    internal func cleanCache() {

    }


    // handles insersion of images into the cache and callback logic
    internal func imageArrived(url:URL, image:UIImage) {
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

