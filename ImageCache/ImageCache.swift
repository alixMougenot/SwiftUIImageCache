//
//  cache.swift
//  ImageCache
//
//  Created by Alix on 26/06/2019.
//

import UIKit

/// Image Cache is an asynchronous image loader that can load images in the background, while keeping a cache of the most recently used.
/// It has two cascading persistance layers. The first one that keeps images in memory for the most recently queried ImageCache.imageMemoryMaxCount images.
/// The second one is on-disk, storing images in the App's cache folder for as long as their `ImageCache.imageTimeToLive`.
/// Memory warnings will trigger all instances to call self.removeAll(), which purges the in-memory storage, without persiting to disk.
/// - note: This class is meant to be used as a singleton. But you can instanciate many ImageCaches to create dedicated caches.
public class ImageCache {

    // the plist file name that is used to load images that are stored on disk.
    internal static let DISK_INDEX_FILENAME = "index"

    // MARK: - Internal State

    // concurrent queue used to protect the cache from concurrent writes.
    internal var queue: DispatchQueue

    // the state for every image to load
    internal var storage: [URL:ImageCacheEntry]

    // the available images from the disk
    internal var diskIndex: [URL:ImageDiskEntry]

    // where we store the disk index and images
    internal var diskCacheDirectoryName: String

    // fast check for cache path creation
    internal var cacheDirectoryCreated: Bool

    // fast check for disk index loaded
    internal var diskCacheIndexLoaded: Bool

    // MARK: - Public Tweaking variables

    /// This variable dicates how long images are considered valid, for both in-memory and on-disk cache layers.
    /// You can change the value if you need to fine control how long images are retained for this instance.
    /// Note that this is per instance of the ImageCache. You can create short lived and long lived caches if you need to have different lifespans.
    /// You cannot set this variable to a value smaller than 1.0
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

    /// This variable dictates how many images are kept in memory. When max is reached, 10% of the max will be evicted form memory to go on-disk.
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

    /// Singleton to access a default shared cache instance accross your App.
    public static let shared = ImageCache(uniqueName:"imageLazyLoadCache")

    /// Creates a dedicated ImageCache. Each instance will run opperations in a dedicated queue and
    /// clear all content upon the system emiting a MemoryWarningNotification.
    /// - parameter uniqueName: a unique name for this cache,
    ///                         the name is used to create a cache folder where images are persisted after in-memory eviction.
    public init (uniqueName: String) {
        self.diskCacheDirectoryName = uniqueName
        self.cacheDirectoryCreated = false
        self.diskCacheIndexLoaded = false
        self.queue = DispatchQueue(label: "ImageCacheAccessQueue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        self.storage = [URL:ImageCacheEntry]()
        self.diskIndex = [URL:ImageDiskEntry]()
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] (_:Notification) in
            self?.removeAll()
        }
        // Note(a.mougenot, 28-Jun-2019): Looks like the block passed to notification center itself will leak.
        //                                It's not so bad because self is a weak reference, and this is intended to be a Singleton.
    }

    // MARK: - API

    /// This function is used to asynchornously fetch an image given its URL.
    /// This fetches transparently from in-memory, on-disk or network depending on availability.
    /// When the image is loaded in-memory the callback is triggered in the main queue, asynchrounously.
    /// If anything wrong happens while fetching the image, such as a network issue or a bad URL, the image passed to the callback will be nil.
    /// - important: the callback is always executed asynchrnously on the main queue. It is executed at best once.
    /// - parameter callback: This callback is called upon the image beeing downloaded or found in the memory/disk cache.
    ///            Multiple call to this method for the same URL will stack the callbacks, they will all be called in the order of the method calls.
    ///            The callback is not called when the request is cancelled or the cache cleared by calling [removeAll](x-source-tag://removeAll).
    ///            The callback is deleted after call to avoid leaking captured variables.
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
                self.storage[url] = newEntry

                return // Nothing more to do, image is already beeing loaded
            }

            // C: here we don't have a valid entry, let's create a fresh one.
            self.storage[url] = ImageCacheEntry(lastUsed: Date(), downloadDate: Date(), url: url, image: nil, loading: true, cancel: false, callback: callback)
            self.cacheRotation() // we just added an entry, maybe cache needs to evict entries.

            DispatchQueue.global().async {
                // C.1: We have it on disk
                self.loadDiskIndexIfNeeded()
                if let imageOnDisk = self.diskIndex[url],
                    Date().timeIntervalSince(imageOnDisk.downloadDate) < self.imageTimeToLive,
                    let image = self.getImageFromDisk(named: imageOnDisk.fileName)  {

                    self.imageArrived(url: url, image: image, downloadDate: imageOnDisk.downloadDate)
                    return
                }


                // C.2: We get it from network
                // Note(a.mougenot, 26-JUN-2019): We could improve this by using a background download task from the system instead of this.
                // Note(a.mougenot, 28-JUN-2019): Using Data(contentsOf:) is not cancelable, maybe consider something more complex.
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    self.imageArrived(url: url, image: image)
                } else {
                    self.imageArrived(url: url, image: nil)
                }
            }
        }
    }


    /// this function asynchronously deletes the image corresponding to the given URL from in-memory, without persiting it to on-disk.
    /// If a download is running for that image, the callback will not be called and the image will not be stored in-memory.
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

    /// Synchronous access to the image cache. This does not fetch the image from network nor disk.
    /// This is a synchonous access to in-memory images.
    /// - parameter url: The URL used to load the image.
    /// - returns: The image if found, nil if the image is not already loaded.
    /// - important: The on-disk cache is not available throuh this method until a fetch request is performed, on-disk can only load asynchronously.
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
    /// Failures to get an image from on-disk are not reported here and trigger a download instead.
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

    /// Synchronous access to the image cache. This will return true iff this instance is currently fetching the image.
    /// Note that this will return true regardless of if fetching from network or disk.
    /// - parameter url: The URL used to load the image.
    /// - returns: true iff the instance is currently fetching the image.
    public func fetching(_ url: URL) -> Bool {
        var result:Bool = false
        self.queue.sync {
            guard let state = self.storage[url] else { return }
            result = state.image == nil && state.loading
        }
        return result
    }


    /// Synchronously frees the memory used by images in cache, on-going downloads will be cancelled.
    /// This method is automatically called when a Memory Warning is emitted.
    /// Tag:removeAll
    public func removeAll() {
        self.queue.sync() {
            self.storage.removeAll() // Note: this will also remove the client callbacks that are stored in the state.
        }
    }

    // MARK: Disk Persistance

    /// Call this method when the App is going in the background if you want to persist the cache on disk for the next run.
    public func persistCacheToDisk() {
        for (_, entry) in self.storage {
            self.persistToDisk(entry)
        }

        self.persistDiskIndex()
    }


    /// Call this method to cleanup the disk cache, ensuring that only maxImageCount images are kept on disk.
    /// Least recent images are deleted first.
    /// This method is asynchronous. Currently running fetch may yield to new disk entries above maxImageCount.
    public func reduceDiskCache(maxImageCount: Int) {
        self.loadDiskIndexIfNeeded()
        let countToDelete = self.diskIndex.count - maxImageCount
        guard countToDelete > 0 else { return }

        let sorted = self.diskIndex.sorted { $0.value.downloadDate < $1.value.downloadDate }
        DispatchQueue.global().async {
            for (key,entry) in sorted.prefix(countToDelete) {
                self.deleteImageFromDisk(named: entry.fileName)
                self.diskIndex.removeValue(forKey: key)
            }

            self.persistDiskIndex()
        }
    }

    // MARK: - Internal Code

    // handles insersion of images into the cache and callback logic
    internal func imageArrived(url:URL, image:UIImage?, downloadDate: Date = Date()) {
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
            state.downloadDate = downloadDate
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

    // MARK: Cache Logic

    // cleans cache to free some space
    // ⚠️ call from within self.queue queue, it accesses shared state to run
    internal func cacheRotation() {
        let now = Date()
        for (key, entry) in self.storage {
            if now.timeIntervalSince(entry.downloadDate) > self.imageTimeToLive {
                self.storage.removeValue(forKey: key) // this is safe: remember that dicts are values, iteration is done on a copy.
            }
        }

        for (key, entry) in self.diskIndex {
            if now.timeIntervalSince(entry.downloadDate) > self.imageTimeToLive {
                self.diskIndex.removeValue(forKey: key)
                // Remove the file
            }
        }

        if self.storage.count < self.imageMemoryMaxCount { return }

        // we will evict 10% of the stored images, regardless of size
        let sortedEntries = self.storage.sorted { $0.value.lastUsed < $1.value.lastUsed } // the smaller the date the older they are
        let retainSize = Int(Double(self.imageMemoryMaxCount) * 0.1) + 1
        for (key, _) in sortedEntries.prefix(retainSize) {
            guard let removedEntry = self.storage.removeValue(forKey: key) else { continue }

            removedEntry.callback?(removedEntry.url, nil) // if still downloading, we want to tell that it failed.
            self.persistToDisk(removedEntry)
        }

        DispatchQueue.global().async { self.persistDiskIndex() }
    }


    // MARK: Disk Storage Logic
    // Note on this section: Disk cache and disk index opperations are, most of the time, not made thread safe.
    //                       This is on puropose not to interlock the in-memory state that is accessed from synchronous methods with disk accesses.
    //                       Disk is a backup mechanism, it is OK if it fails.


    // makes sure we have the directory where the index and the images will be stored
    internal func ensureCacheDirectoryExists() {
        guard !self.cacheDirectoryCreated else { return }
        self.cacheDirectoryCreated = true // not thread safe but this opperation is omnipotent

        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let myPath = cacheDirectory.appendingPathComponent(self.diskCacheDirectoryName)

        do {
            try FileManager.default.createDirectory(at: myPath, withIntermediateDirectories: true, attributes: nil)
        } catch _  {
            // will fail when already created, it's fine.
        }
    }

    // this function creates an on-disk version of the given in-memory entry. The entry is added to the index and the image persisted to disk.
    // You need to manually call self.persistDiskIndex() after you are done inserting on-disk entries.
    // You can call from within self.queue queue to avoid inconsistencies, disk write opperations are run on a global queue.
    internal func persistToDisk(_ entry: ImageCacheEntry) {
        guard entry.image != nil else { return }

        let diskEntry = ImageDiskEntry(downloadDate: entry.downloadDate, url: entry.url, fileName: "\(entry.url.absoluteString.hashValue).png")
        self.diskIndex[diskEntry.url] = diskEntry

        DispatchQueue.global().async {
            self.ensureCacheDirectoryExists()
            let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let myPath = cacheDirectory.appendingPathComponent(self.diskCacheDirectoryName)
            let imageURL = myPath.appendingPathComponent(diskEntry.fileName)

            guard let data = entry.image?.pngData() ?? entry.image?.jpegData(compressionQuality: 1.0) else { return } // we can't encode, it too bad
            try? data.write(to: imageURL)
        }
    }


    // utility to delete the image file for the given name, does not remove from index.
    internal func deleteImageFromDisk(named filename: String) {
        self.ensureCacheDirectoryExists()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let myPath = cacheDirectory.appendingPathComponent(self.diskCacheDirectoryName)
        let imageURL = myPath.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: imageURL)
    }

    // reads the image file for the given name, returns nil if image is missing or corrupted.
    internal func getImageFromDisk(named filename: String) -> UIImage? {
        self.ensureCacheDirectoryExists()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let myPath = cacheDirectory.appendingPathComponent(self.diskCacheDirectoryName)
        let imageURL = myPath.appendingPathComponent(filename)

        guard let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }


    // loads the on-disk cache index into memory, if needed, synchronously.
    internal func loadDiskIndexIfNeeded() {
        guard !self.diskCacheIndexLoaded else { return }
        self.diskCacheIndexLoaded = true // not very thead safe, but the code is omnipotent

        self.ensureCacheDirectoryExists()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let myPath = cacheDirectory.appendingPathComponent(self.diskCacheDirectoryName)
        let fileURL = myPath.appendingPathComponent("\(ImageCache.DISK_INDEX_FILENAME).json")

        if let data = try? Data(contentsOf: fileURL),
            let stored = try? JSONSerialization.jsonObject(with: data, options: []),
            let dict = stored as? [String:[String:Codable]] {
            for (key, encoded) in dict {
                guard let url = URL(string: key), let val = ImageDiskEntry(fromEncoded: encoded) else { continue }
                self.diskIndex[url] = val
            }
        }
    }


    // writes the plist of the disk cache into memory.
    internal func persistDiskIndex() {
        self.ensureCacheDirectoryExists()
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let myPath = cacheDirectory.appendingPathComponent(self.diskCacheDirectoryName)
        let fileURL = myPath.appendingPathComponent("\(ImageCache.DISK_INDEX_FILENAME).json")

        var toStore = [String:[String:Codable]]()
        for (key, val) in self.diskIndex {
            toStore[key.absoluteString] = val.toEncodable()
        }

        let data = try? JSONSerialization.data(withJSONObject: toStore, options: [])
        let _ = try? data?.write(to: fileURL)
    }

}

// MARK: - Cache Entry Types

/// This represent the in-memory loading state of a given image
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


/// This represent a disk persisted version of an image.
/// - Note: This type do look like ImageCacheEntry, but the useage is very different, merging these types would make the code much more complex.
internal struct ImageDiskEntry {
    /// used to delete images that are older than the time to live.
    var downloadDate: Date

    /// The url is copied here so that we can rely on something else to index the images in the future.
    var url: URL

    /// where to get the file
    var fileName: String
}

// Extention to help with encoding/decoding because both URL and Date are not Codable.
extension ImageDiskEntry {
    // helper for serialization.
    func toEncodable() -> [String:Codable] {
        return ["downloadDate":self.downloadDate.timeIntervalSince1970,
                "fileName":self.fileName,
                "url":self.url.absoluteString ]
    }

    // helper to deserialize the type
    init?(fromEncoded dict:[String:Codable]) {
        guard let downloadDate = dict["downloadDate"] as? TimeInterval,
            let filenameStr = dict["fileName"] as? String,
            let urlStr = dict["url"] as? String,
            let urlDecoded = URL(string: urlStr) else { return nil }

        self.downloadDate = Date(timeIntervalSince1970: downloadDate)
        self.fileName = filenameStr
        self.url = urlDecoded
    }
}

