
## Introduction
ImageLoader is a lightweight iOS swift library for asynchronous UIKit/UIImage fetch. It's design to help with loading images unsed in collections by keeping a controlled cache of downloaded images accross your Application. It features a cascading in-memory then on-disk caching system.

It features:
1. Async download of images, callback style.
2. Synchronous access to downloaded image. It is a UImage cache.
3. Controllable Disk persistance of the images, for faster fetch after a reboot or after an image is evicted from in-memory.
4. The library will discard all in-memory images upon the Application firing a Memory Warning Notification, you don't have to handle that.

This is a single file project: [ImageCache.swift](./ImageCache/ImageCache.swift)

## Usage

To load an image asynchronously, you can do something like this. Note that the library will take care of keeping the image in cache, successive calls to fetch will imediatly call the callback with the cached image. You don't have to worry about loading the library, on-disk cache is loaded at the first call to fetch:
``` Swift
// Setup a Loading State
imageView.image = UIImage(named:"loading_placeholder")
ImageCache.shared.fetch(imageURL) { (loadedURL:URL, image:UIImage?) in
    // This block is executed on mainQueue

    guard let foundImage = image else {
        // Setup an Error State (you may want to retry that URL)
        imageView.image = UIImage(named:"error_placeholder")
        return
    }

    // Setup the Nominal State
    imageView.image = foundImage
}
```

If you want to handle a CollectionView or a TableView, we dont recommend async callbacks because cells are recycled. Here is how to use the synchronous cache access to deal with recycled views:

```Swift
if let alreadyLoadedImage = ImageCache.shared.peek(imageUrl) {
    // Nominal State
    cell.imageView?.image = alreadyLoadedImage

} else if ImageCache.shared.failedToFetch(url) {
    // Error State
    cell.imageView?.image = UIImage(named:"error_placeholder")

} else {
    // Loading State
    cell.imageView?.image = UIImage(named:"loading_placeholder")

    ImageCache.shared.fetch(url) { (loadedURL:URL, image:UIImage?) in
        // This is in mainQueue, but let's leave room for animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { 
            self.tableview.reloadRows(at: [indexPath], with: .fade) // will yeild a cache hit
        }
    }
}
```
The library will handle caching, evicting from cache, using disk-cache over network on its own. See next section on how to tweak this behavior.

A more comprehensive example is inlcuded in the example App [MainViewController.swift](./ExampleApp/ImageCacheExampleApp/MainViewController.swift). Note that the images used in the example project are extracted from Instagram traffic, some of the images may not be available from the CDN anymore.

## Install the Library

#### CocoaPods

```Ruby
pod 'ImageCache', :git => 'https://github.com/alixMougenot/SwiftUIImageCache.git'
```

#### Include the file
You can simply copy [ImageCache.swift](./ImageCache/ImageCache.swift) to your project. The library is contained in this file for easy include.

You can try to drag and drop the **ImageCache** folder and target from the Project to your own to create a new private module (or simply create a new module and copy the source file to it). Don't forget to add the **ImageCache.framework** to *Included Binaries* so that it gets shipped with the App. If your code is in OBJ-C don't forget to set *EMBEDDED_CONTENT_CONTAINS_SWIFT* to *YES* in your App target.

### Run the Example App from XCode
The test App is using CocoaPods for dependency management:
```Bash
cd ExampleApp/
pod install
open ImageCacheExampleApp.xcworkspace
```

## Cache Control
The cache mechanism can be controlled:
- You can setup a timeToLive for images, images that are older than timeToLive will be deleted, and re-downloaded at the next fetch.
- You can setup a maximum number of images to keep in the in-memory cache. Evicted entries will be stored on-disk, in a cache folder.
- You can regulate the on-disk cache size by calling ```reduceDiskCache(maxImageCount: Int)``` when needed.
- The library will discard all in-memory images upon the Application fiering a Memroy Warning Notification, you don't have to do anything for that.

```Swift
/// This variable dicates how long images are considered valid, for both in-memory and on-disk cache layers.
/// You can change the value if you need to fine control how long images are retained for this instance.
/// Note that this is per instance of the ImageCache. You can create short lived and long lived caches if you need to have different lifespans.
/// You cannot set this variable to a value smaller than 1.0
public var imageTimeToLive: TimeInterval = 10 * 60.0

/// This variable dictates how many images are kept in memory. When max is reached, 10% of the max will be evicted form memory to go on-disk.
/// You cannot set this value smaller than 1.
public var imageMemoryMaxCount: Int = 100 
```

Note that you can create many ImageCache instances if you want to handle images with different lifespans.

## Disk Persitence
The library will store to disk images when there is not enough room in memory. You can also persit the current in-memory cache before going in the background to load images faster and save bandwidth for the next run.
```Swift
func applicationWillResignActive(_ application: UIApplication) {
        // saving current image cache
        ImageCache.shared.persistCacheToDisk()
}
```

## More?
Please read the documentation of [ImageCache.swift](./ImageCache/ImageCache.swift) for more features like cancelling fetch, deleting entries, etc.

## Disclaimer
This project is poorly tested. If you want to use this in Production, please comtribute to the test effort to make this library safer. Testing asynchronous code is unfortunately difficult.

## Contribute
There are a few notes in the code where improvements are needed, don't hesitate to send merge requests for these or add new ones in the code.


