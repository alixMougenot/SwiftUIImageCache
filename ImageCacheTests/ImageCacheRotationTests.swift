//
//  ImageCacheTests.swift
//  ImageCacheTests
//
//  Created by Alix on 26/06/2019.
//

import XCTest
@testable import ImageCache

class ImageCacheRotationTests: XCTestCase {
    let cache: ImageCache = ImageCache(uniqueName: "testing")

    override func setUp() {
        self.cache.reduceDiskCache(maxImageCount: 100)
        self.cache.imageMemoryMaxCount = 5
    }

    override func tearDown() {
        self.cache.reduceDiskCache(maxImageCount: 0)
    }

    // Tests that the rotation does actually delete entries
    func testRotationDeletesEntries() {
        DispatchQueue.global().sync {
            let waiter = XCTestExpectation(description: "Waiting for all downloads")
            var done = 0

            for i in 30...40 {
                guard let url = URL(string: "https://picsum.photos/id/\(i)/200/200") else {
                    XCTAssert(false)
                    continue
                }

                self.cache.fetch(url) { (url:URL, image:UIImage?) in
                    done += 1
                    if done == 10 {
                        waiter.fulfill()
                    }
                }
            }

            wait(for: [waiter], timeout: 20.0)
            XCTAssert(self.cache.storage.count < 6)
        }
    }


    // tests that the rotation of the cache keeps the most recents
    func testRotationKeepsMostRecent() {
        DispatchQueue.global().sync {

            for i in 30...40 {
                guard let url = URL(string: "https://picsum.photos/id/\(i)/200/200") else {
                    XCTAssert(false)
                    continue
                }

                // we are serializing the calls so that entries get a download date in the same order as the requests
                let waiter = XCTestExpectation(description: "Waiting for \(url)")
                self.cache.fetch(url) { (url:URL, image:UIImage?) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                        waiter.fulfill()
                    }
                }

                wait(for: [waiter], timeout: 10.0)
            }


            // checking that the last downlaoded are kept in memory
            for i in 38...40 { // 38 is safe, the rotation leaves size - (10% + 1) -> 5 - 2 -> 3
                guard let url = URL(string: "https://picsum.photos/id/\(i)/200/200") else {
                    XCTAssert(false)
                    continue
                }
                XCTAssert(self.cache.peek(url) != nil)
            }


            // checking that the first downlaoded are evicted
            for i in 30...35 {
                guard let url = URL(string: "https://picsum.photos/id/\(i)/200/200") else {
                    XCTAssert(false)
                    continue
                }
                XCTAssert(self.cache.peek(url) == nil)
            }

        }
    }



}
