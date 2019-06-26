//
//  ViewController.swift
//  ImageCacheExample
//
//  Created by Alix on 26/06/2019.
//  Copyright © 2019 AM. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    // MARK: Table View thing
    @IBOutlet var tableview: UITableView!

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else {
            return 0
        }

        return urls.count
    }


    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let recycle = tableView.dequeueReusableCell(withIdentifier: "photo", for: indexPath)
        return recycle
    }



    let urls = [
        "https://scontent-cdg2-1.cdninstagram.com/vp/36cbaeb096f0eadbaf16b5c843cdaa38/5DA4728C/t51.2885-15/sh0.08/e35/s640x640/64868582_894314034242775_4615919503840261830_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/1f2d233c5fd2a9876cc0c1574ae299fe/5D1596F5/t51.2885-15/e35/c0.80.640.640a/65493614_339900636705001_8047809173724794606_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/c193b40a87e5aae75779fa5778766c71/5D168480/t51.2885-15/sh0.08/e35/c0.90.720.720a/s640x640/62372400_428394194667401_1517352029248801660_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/8ca4f8a84759d7f1cc4215d2b7ac856a/5DA2CFEB/t51.2885-15/sh0.08/e35/s640x640/62530030_478809979552132_6901584951444626290_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/f4dd8aedda355a50e5f35dd98b4c2ef7/5DA53DCF/t51.2885-15/sh0.08/e35/s640x640/64895377_454427395390016_7510140141915897035_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",

        "https://scontent-cdg2-1.cdninstagram.com/vp/13c0d9a5c63cc6eaa412db84a1676cdb/5DA5E218/t51.2885-15/sh0.08/e35/s640x640/62258957_445143532931303_7819194460393565519_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/781b369a1817b9520d4a6e440dc9ace5/5D168492/t51.2885-15/e35/c0.80.640.640a/62561019_2357260431261401_6506410304292465089_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/29e7aff2d22478df7e3d7be96a209386/5DAB01CF/t51.2885-15/e35/64366415_156815022036183_6141184519447019110_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/09d9098599cab47adb9f7e0359c9768a/5D1601CF/t51.2885-15/e35/c0.80.640.640/65261728_595301677628717_7494976783626255443_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",

        "https://scontent-cdg2-1.cdninstagram.com/vp/abd342580481265288bc94cfb71fd6ba/5D15B862/t51.2885-15/e35/c0.60.480.480a/64301780_2270976043166498_6793085958574096641_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/2548bff4b9058072559fdb9953c7390e/5DB770A9/t51.2885-15/sh0.08/e35/s640x640/62556239_2844771475592971_8875379001114394570_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/a1c316da21cd24a0131af3ef3e493fae/5D15A7D0/t51.2885-15/e35/c0.60.480.480a/64676592_402747373918731_5953163385582323624_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/d9ecafc6d4ed4cf1e8bd0eff349c7bc8/5DAB5784/t51.2885-15/sh0.08/e35/c0.180.1440.1440/s640x640/62644457_447367566051139_1559215937463492588_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/03ad2b514a915c3ee57aa0f92787950c/5D159266/t51.2885-15/sh0.08/e35/c0.90.720.720a/s640x640/65272118_361331527860014_4301065399452291761_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/58ec3c93ee931e276f9c2d3d56690a35/5D15AA13/t51.2885-15/e35/c0.60.480.480a/64403328_619685981878164_5518494050688202282_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/2912752f5c9951df6bdaf0183a1fedae/5D1629C6/t51.2885-15/e35/c0.60.480.480a/65007712_766791243716290_6921758190115926695_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/66b0a882094cf410b5c34dcefdbe9f71/5D16152D/t51.2885-15/sh0.08/e35/s640x640/64330059_111464230129488_1350192391069440148_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/094f50c976f3657c6679219728018a3e/5DBFCB6B/t51.2885-15/sh0.08/e35/s640x640/64773890_179242563098462_6644529816937827770_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/d229686add0cd9711887ee1df4186183/5D16A072/t51.2885-15/sh0.08/e35/c0.90.720.720a/s640x640/61965428_1032065590335928_5604966045887354997_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/a706cf62b60535d44fddfa1b2e4bdf3a/5DB107EF/t51.2885-15/sh0.08/e35/c0.154.1239.1239a/s640x640/64251557_141768420236113_3138313376553130467_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/fca47847cd8d0d21c6140bcbac58ca2a/5DC7096D/t51.2885-15/sh0.08/e35/s640x640/62208156_2407594532635835_9047072742608287791_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/bb0d8ecc87be69697b44f5ee47e80800/5D167F9F/t51.2885-15/sh0.08/e35/s640x640/64588723_456771388431546_7458109120464930465_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/5a32bb61505766cd3b31f753c3a998d1/5D1688F8/t51.2885-15/sh0.08/e35/s640x640/64777110_194786844841373_3629655425332214136_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/673f6ac368b8671592aa87fa53888e13/5DBCE305/t51.2885-15/sh0.08/e35/s640x640/61716899_625590764607993_9221796566274393823_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/13c0d9a5c63cc6eaa412db84a1676cdb/5DA5E218/t51.2885-15/sh0.08/e35/s640x640/62258957_445143532931303_7819194460393565519_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/cda41b5b9af99978d02f7f45f6c282c6/5DB6DD9E/t51.2885-15/sh0.08/e35/c135.0.810.810a/s640x640/19984976_1538931852833457_3600335234421227520_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/511c291e5bef8ac25efeb69dc139b1ce/5DBA76D1/t51.2885-15/sh0.08/e35/c0.135.1080.1080a/s640x640/50115211_297239940995118_8190868858006396245_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/9800ab42f5f4004d199f4032b419c6c5/5DAA6A13/t51.2885-15/sh0.08/e35/s640x640/20393703_681680132023980_9192137003158732800_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/86be3334fd3cfd08fbd75df4d850622c/5DA515DD/t51.2885-15/sh0.08/e35/s640x640/32178317_2074316695930488_1010981137645830144_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/2b31cb1fcbbdcaf2fea3ef6cffcc23fd/5DBBB088/t51.2885-15/sh0.08/e35/c0.134.1080.1080a/s640x640/39300569_1863991423656160_3209764776972386304_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
         "https://scontent-cdg2-1.cdninstagram.com/vp/08c4031b6c0a5285c1f159157195a9e7/5DBD8B6A/t51.2885-15/sh0.08/e35/c135.0.810.810a/s640x640/16789616_771764409647774_1639207365536382976_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/18a56292ea1ed08d35defc60fb6dabb5/5DACA902/t51.2885-15/sh0.08/e35/c0.120.960.960a/s640x640/33879377_195725164409773_3238417594725695488_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com",
        "https://scontent-cdg2-1.cdninstagram.com/vp/eac89e3799d6bae99a5c08e869b7963e/5DA57317/t51.2885-15/sh0.08/e35/s640x640/23507596_1491664764284929_1578895772613607424_n.jpg?_nc_ht=scontent-cdg2-1.cdninstagram.com"
    ]
}

