//
//  ViewController.swift
//  iTunes Artwork Grabber iOS
//
//  Created by Scarlet on 30/11/2018.
//  Copyright © 2018 Scarlet. All rights reserved.
//

import UIKit

let countries = cList().getList()
var allCountries = [String]()
var countriesArray = [String]()
let userDefault = UserDefaults.standard

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return results.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let artworkCell = collectionView.dequeueReusableCell(withReuseIdentifier: "artwork", for: indexPath) as! artworkCell
        let key = keys[indexPath.row]
        let img = imgs[key]
        
        artworkCell.artwork.image = img
        
        return artworkCell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectCell = collectionView.dequeueReusableCell(withReuseIdentifier: "artwork", for: indexPath) as! artworkCell
        let key = keys[indexPath.row]
        let img = imgs[key]
        let alert = UIAlertController(title: key, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save to Camera Roll", style: .default, handler: { _ in
            UIImageWriteToSavedPhotosAlbum(img!, nil, nil, nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if UIDevice.current.modelName == "iPad" || UIDevice.current.modelName == "Simulator"{
            if let popoverPresentationController = alert.popoverPresentationController{
                popoverPresentationController.sourceView = collectionView
                popoverPresentationController.sourceRect = selectCell.artwork.frame
            }
        }
        self.present(alert, animated: true, completion: nil)
    }
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return countriesArray.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return countriesArray[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        countryList.text = countriesArray[row]
    }
    
    @IBOutlet weak var query: UITextField!
    @IBOutlet weak var countryList: UITextField!
    @IBOutlet weak var artworkList: UICollectionView!
    @IBOutlet weak var searchBtn: UIButton!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var sourceSeg: UISegmentedControl!
    @IBAction func search(_ sender: UIButton) {
        width = userDefault.integer(forKey: "width")
        height = userDefault.integer(forKey: "height")
        if width == 0{
            width = 100
        }
        if height == 0{
            height = 100
        }
        results.removeAll()
        keys.removeAll()
        //imgs.removeAll()
        artworkList.reloadData()
        
        switch sourceSeg.selectedSegmentIndex{
        case 0:
            for ctry in countries{
                if ctry.value == countryList.text{
                    getJSON(query: query.text!, code: ctry.key)
                    break
                }else{
                    continue
                }
            }
            
        case 1:
            var request = URLRequest(url: URL(string: "https://www.sonymusic.co.jp/json/search/category/artist/start/0/count/99")!)
            var counter = 0
            var dataString = String()
            var responseText = [String: String]()
            
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "post"
            if let content = query.text{
                request.httpBody = ("word=" + content).data(using: .utf8)
                print(content)
            }
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    return
                }
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                    // check for http errors
                    return
                }
                
                dataString = String(data: data, encoding: .utf8)!
                dataString = dataString.replacingOccurrences(of: "callback(", with: "")
                dataString = dataString.replacingOccurrences(of: ")", with: "")
                
                var jsonResult = NSDictionary()
                
                do{
                    jsonResult = try JSONSerialization.jsonObject(with: dataString.data(using: .utf8)!, options:.allowFragments) as! NSDictionary
                } catch let error as NSError {
                    print(error)
                }
                if let resultCount = jsonResult.value(forKey: "items") as? NSArray{
                    if resultCount.count > 0{
                        for item in resultCount{
                            if let artist = (item as! NSDictionary)["artistName"] as? String, let artistPage = (item as! NSDictionary)["artistPage"] as? String{
                                print("Start Download")
                                
                                responseText[artist] = artistPage
                                
                                counter += 1
                                if counter == resultCount.count{
                                    DispatchQueue.main.async {
                                        let alert = UIAlertController(title: nil, message: "Select artist to begin search.", preferredStyle: .actionSheet)
                                        
                                        for (artist, artistPage) in responseText{
                                            alert.addAction(UIAlertAction(title: artist, style: .default, handler: { _ in
                                                self.getSONY(artistPage: artistPage)
                                            }))
                                        }
                                        
                                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                                        self.present(alert, animated: true, completion: nil)
                                    }
                                }
                                
                            }
                        }
                    }else{
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Cannot found result", message: nil, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
                
            }
            task.resume()
            
        default:
            break
        }
        
    }
    @IBAction func sourceChange(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex{
        case 1:
            countryList.isEnabled = false
        default:
            countryList.isEnabled = true
        }
    }
    
    
    let countryPick = UIPickerView()
    
    var width = Int()
    var height = Int()
    var results = [String:String]()
    var keys = [String]()
    var imgs = [String:UIImage]()
    
    
    @objc func dismissPicker(){
        view.endEditing(true)
    }
    func getSONY(artistPage: String){
        var dataString = String()
        print("https://www.sonymusic.co.jp/json\(artistPage)discography/start/0/count/99")
        let url: URL = URL(string: "https://www.sonymusic.co.jp/json\(artistPage)discography/start/0/count/99")!
        let defaultSession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
        let task = defaultSession.dataTask(with: url) {
            (data, response, error) in
            if error != nil {
                print("Failed to download data")
            }else {
                dataString = String(data: data!, encoding: .utf8)!
                dataString = dataString.replacingOccurrences(of: "callback(", with: "")
                dataString = dataString.replacingOccurrences(of: ")", with: "")
                self.parseSONY(dataString.data(using: .utf8)!)
            }
        }
        task.resume()
    }
    func parseSONY(_ data: Data){
        var jsonResult = NSDictionary()
        do{
            jsonResult = try JSONSerialization.jsonObject(with: data, options:.allowFragments) as! NSDictionary
        } catch let error as NSError {
            print(error)
        }
        if let resultCount = jsonResult.value(forKey: "items") as? NSArray{
            if resultCount.count > 0{
                for item in resultCount{
                    if var jacket = (item as! NSDictionary)["jacketImage"] as? String, let artist = (item as! NSDictionary)["artistName"] as? String, let jTitle = (item as! NSDictionary)["title"] as? String{
                        print("Start Download")
                        
                        jacket = jacket.replacingOccurrences(of: "240_240", with: "\(width)_\(height)")
                        let fullString = artist + " - " + jTitle
                        self.results[fullString] = "https://www.sonymusic.co.jp" + jacket
                        print("https://www.sonymusic.co.jp" + jacket)
                    }
                    keys = Array(results.keys)
                    downloadImg(num: resultCount.count)
                }
            }else{
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Cannot found result", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    func getJSON(query: String, code: String){
        let queryP = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let url: URL = URL(string: "https://itunes.apple.com/search?term=\(queryP)&country=\(code)&entity=album")!
        let defaultSession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
        let task = defaultSession.dataTask(with: url) {
            (data, response, error) in
            if error != nil {
                print("Failed to download data")
            }else {
                self.parseJSON(data!)
            }
        }
        task.resume()
    }
    func parseJSON(_ data: Data){
        var jsonResult = NSDictionary()
        do{
            jsonResult = try JSONSerialization.jsonObject(with: data, options:.allowFragments) as! NSDictionary
        } catch let error as NSError {
            print(error)
        }
        if let resultCount = jsonResult.value(forKey: "resultCount") as? Int{
            if resultCount > 0{
                let jsonElement = jsonResult.value(forKey: "results") as! NSArray
                for dict in jsonElement{
                    if var imgURL: String = (dict as! NSDictionary).value(forKey: "artworkUrl60") as? String, let artist: String = (dict as! NSDictionary).value(forKey: "artistName") as? String, let album = (dict as! NSDictionary).value(forKey: "collectionName") as? String{
                        imgURL = imgURL.replacingOccurrences(of: "60x60bb", with: "\(width)x\(height)-999")
                        let fullString = artist + " - " + album
                        self.results[fullString] = imgURL
                    }
                }
                keys = Array(results.keys)
                downloadImg(num: resultCount)
            }else{
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Cannot found result", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
    }
    func downloadImg(num: Int){
        let group = DispatchGroup()
        let msg = { () -> String in
            if self.width > 1000 || self.height > 1000 {
                return "High Resolution Artwork requested, it might require longer download time."
            }else{
                return String()
            }
        }
        
        let alert = UIAlertController(title: "Downloading \(num) artwork\(num > 1 ? "s" : "")...", message: msg(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Run in Background", style: .default, handler: { _ in
            DispatchQueue.main.async {
                self.spinner.isHidden = false
                self.countryList.isEnabled = false
                self.searchBtn.isEnabled = false
                self.query.isEnabled = false
            }
        }))
        var counter = 0
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
        for (key, value) in results{
            group.enter()
            print("Start Download")
            DispatchQueue.global(qos: .default).async {
                DownloadPhoto().get(url: URL(string: value)!) { data, response, error in
                    guard let imgData = data, error == nil else { counter = counter + 1; return }
                    self.imgs[key] = UIImage(data: imgData)
                    counter = counter + 1
                    group.leave()
                    if counter == self.results.count{
                        DispatchQueue.main.async {
                            print("Download Complete")
                            alert.dismiss(animated: true, completion: nil)
                            self.artworkList.reloadData()
                            DispatchQueue.main.async {
                                self.spinner.isHidden = true
                                self.countryList.isEnabled = true
                                self.searchBtn.isEnabled = true
                                self.query.isEnabled = true
                            }
                        }
                    }
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        width = userDefault.integer(forKey: "width")
        height = userDefault.integer(forKey: "height")
        if width == 0{
            width = 100
        }
        if height == 0{
            height = 100
        }
        
        for ctry in countries{
            allCountries.append(ctry.value)
        }
        allCountries.sort()
        
        countryPick.delegate = self
        countryPick.dataSource = self
        artworkList.delegate = self
        artworkList.dataSource = self
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if userDefault.array(forKey: "countriesArray")?.isEmpty ?? true{
            for ctry in countries{
                countriesArray.append(ctry.value)
            }
            countriesArray.sort()
            userDefault.set(countriesArray, forKey: "countriesArray")
        }else{
            for ctry in userDefault.array(forKey: "countriesArray")!{
                if (ctry as! String) != "null"{
                    countriesArray.append((ctry as! String))
                }
            }
        }
        
        let toolBar = UIToolbar()
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissPicker))
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.sizeToFit()
        toolBar.setItems([spaceButton, cancelButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        countryPick.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height/2)
        countryList.inputView = countryPick
        countryList.inputAccessoryView = toolBar
        if countriesArray.count > 0{
            countryList.text = countriesArray[0]
            countryList.isEnabled = true
            searchBtn.isEnabled = true
        }else{
            countryList.isEnabled = false
            searchBtn.isEnabled = false
        }
        query.inputAccessoryView = toolBar
        countryPick.reloadAllComponents()
        
    }
    
}

class artworkCell: UICollectionViewCell{
    @IBOutlet weak var artwork: UIImageView!
    @IBOutlet weak var dummyView: UIView!
}

class trySailViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource{
    
    var width = 1000
    var height = 1000
    
    var results = [UIImage]()
    var jacketTitle = [String]()
    @IBOutlet weak var artworkList: UICollectionView!
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return results.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "artwork", for: indexPath) as! artworkCell
        
        cell.artwork.image = results[indexPath.row]
        
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectCell = collectionView.dequeueReusableCell(withReuseIdentifier: "artwork", for: indexPath) as! artworkCell
        let alert = UIAlertController(title: jacketTitle[indexPath.row], message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save to Camera Roll", style: .default, handler: { _ in
            UIImageWriteToSavedPhotosAlbum(self.results[indexPath.row], nil, nil, nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if UIDevice.current.modelName == "iPad" || UIDevice.current.modelName == "Simulator"{
            if let popoverPresentationController = alert.popoverPresentationController{
                popoverPresentationController.sourceView = collectionView
                popoverPresentationController.sourceRect = selectCell.artwork.frame
            }
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    func parseJSON(_ data: Data){
        var jsonResult = NSDictionary()
        var counter = 0
        do{
            jsonResult = try JSONSerialization.jsonObject(with: data, options:.allowFragments) as! NSDictionary
        } catch let error as NSError {
            print(error)
        }
        if let resultCount = jsonResult.value(forKey: "items") as? NSArray{
            if resultCount.count > 0{
                for item in resultCount{
                    if let jacket = (item as! NSDictionary)["jacketImage"] as? String, let artist = (item as! NSDictionary)["artistName"] as? String, let jTitle = (item as! NSDictionary)["title"] as? String{
                        print("Start Download")
                        
                            DownloadPhoto().get(url: URL(string: "https://www.sonymusic.co.jp" + jacket.replacingOccurrences(of: "240_240", with: "\(width)_\(height)"))!) { data, response, error in
                                guard let imgData = data, error == nil else { return }
                                
                                self.results.append(UIImage(data: imgData)!)
                                self.jacketTitle.append(artist + " - " + jTitle)
                                counter = counter + 1
                                
                                if counter == resultCount.count{
                                    DispatchQueue.main.async {
                                        print("Download Complete")
                                        self.artworkList.reloadData()
                                    }
                                }
                            }
                        
                    }
                }
            }else{
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Cannot found result", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        width = userDefault.integer(forKey: "width")
        height = userDefault.integer(forKey: "height")
        
        artworkList.delegate = self
        artworkList.dataSource = self
        
        var dataString = String()
        
        let url: URL = URL(string: "https://www.sonymusic.co.jp/json/artist/trysail/discography/start/0/count/99")!
        let defaultSession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
        let task = defaultSession.dataTask(with: url) {
            (data, response, error) in
            if error != nil {
                print("Failed to download data")
            }else {
                dataString = String(data: data!, encoding: .utf8)!
                dataString = dataString.replacingOccurrences(of: "callback(", with: "")
                dataString = dataString.replacingOccurrences(of: ")", with: "")
                self.parseJSON(dataString.data(using: .utf8)!)
            }
        }
        task.resume()
        
    }
    
}

class soraViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource{
    
    var jacketTitle = [String]()
    var results = [UIImage]()
    var width = 1000
    var height = 1000
    
    @IBOutlet weak var artworkList: UICollectionView!
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return results.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "artwork", for: indexPath) as! artworkCell
        
        cell.artwork.image = results[indexPath.row]
        
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectCell = collectionView.dequeueReusableCell(withReuseIdentifier: "artwork", for: indexPath) as! artworkCell
        let alert = UIAlertController(title: jacketTitle[indexPath.row], message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save to Camera Roll", style: .default, handler: { _ in
            UIImageWriteToSavedPhotosAlbum(self.results[indexPath.row], nil, nil, nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        if UIDevice.current.modelName == "iPad" || UIDevice.current.modelName == "Simulator"{
            if let popoverPresentationController = alert.popoverPresentationController{
                popoverPresentationController.sourceView = collectionView
                popoverPresentationController.sourceRect = selectCell.artwork.frame
            }
        }
        self.present(alert, animated: true, completion: nil)
    }
    
    func parseJSON(_ data: Data){
        var jsonResult = NSDictionary()
        var counter = 0
        do{
            jsonResult = try JSONSerialization.jsonObject(with: data, options:.allowFragments) as! NSDictionary
        } catch let error as NSError {
            print(error)
        }
        if let resultCount = jsonResult.value(forKey: "items") as? NSArray{
            if resultCount.count > 0{
                for item in resultCount{
                    if let jacket = (item as! NSDictionary)["jacketImage"] as? String, let artist = (item as! NSDictionary)["artistName"] as? String, let jTitle = (item as! NSDictionary)["title"] as? String{
                        print("Start Download")
                        
                        DownloadPhoto().get(url: URL(string: "https://www.sonymusic.co.jp" + jacket.replacingOccurrences(of: "240_240", with: "\(width)_\(height)"))!) { data, response, error in
                            guard let imgData = data, error == nil else { return }
                            
                            self.results.append(UIImage(data: imgData)!)
                            self.jacketTitle.append(artist + " - " + jTitle)
                            counter = counter + 1
                            
                            if counter == resultCount.count{
                                DispatchQueue.main.async {
                                    print("Download Complete")
                                    self.artworkList.reloadData()
                                }
                            }
                        }
                        
                    }
                }
            }else{
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Cannot found result", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        width = userDefault.integer(forKey: "width")
        height = userDefault.integer(forKey: "height")
        
        artworkList.delegate = self
        artworkList.dataSource = self
        
        var dataString = String()
        
        let url: URL = URL(string: "https://www.sonymusic.co.jp/json/artist/amamiyasora/discography/start/0/count/99")!
        let defaultSession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
        let task = defaultSession.dataTask(with: url) {
            (data, response, error) in
            if error != nil {
                print("Failed to download data")
            }else {
                dataString = String(data: data!, encoding: .utf8)!
                dataString = dataString.replacingOccurrences(of: "callback(", with: "")
                dataString = dataString.replacingOccurrences(of: ")", with: "")
                self.parseJSON(dataString.data(using: .utf8)!)
            }
        }
        task.resume()
        
    }
    
}

class sonySearchViewController: UIViewController{
    
    @IBOutlet weak var query: UITextField!
    @IBAction func search(_ sender: UIButton) {
        
        var dataString = String()
        var responseText = String()
        var request = URLRequest(url: URL(string: "https://www.sonymusic.co.jp/json/search/category/artist/start/0/count/99")!)
        var counter = 0
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "post"
        if let content = query.text{
            request.httpBody = ("word=" + content).data(using: .utf8)
            print(content)
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                // check for http errors
                return
            }
            
            dataString = String(data: data, encoding: .utf8)!
            dataString = dataString.replacingOccurrences(of: "callback(", with: "")
            dataString = dataString.replacingOccurrences(of: ")", with: "")
            
            var jsonResult = NSDictionary()
            
            do{
                jsonResult = try JSONSerialization.jsonObject(with: dataString.data(using: .utf8)!, options:.allowFragments) as! NSDictionary
            } catch let error as NSError {
                print(error)
            }
            if let resultCount = jsonResult.value(forKey: "items") as? NSArray{
                if resultCount.count > 0{
                    for item in resultCount{
                        if let artist = (item as! NSDictionary)["artistName"] as? String, let artistPage = (item as! NSDictionary)["artistPage"] as? String{
                            print("Start Download")
                            
                            responseText += artist + ": \nPage: " + artistPage + "\n\n"
                            counter += 1
                            if counter == resultCount.count{
                                DispatchQueue.main.async {
                                    let alert = UIAlertController(title: nil, message: responseText, preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                }
                            }
                            
                        }
                    }
                }else{
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Cannot found result", message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
            
        }
        task.resume()
        
        
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
}

class settingsTableViewController: UITableViewController{
    
    @IBOutlet weak var widthValue: UITextField!
    @IBOutlet weak var heightValue: UITextField!
    @IBAction func textChange(_ sender: UITextField) {
        updateDefaults()
    }
    
    @objc func dismissPicker(){
        view.endEditing(true)
        updateDefaults()
    }
    func updateDefaults(){
        guard let width = Int(widthValue.text!) else {return}
        guard let height = Int(heightValue.text!) else {return}
        userDefault.set(width, forKey: "width")
        userDefault.set(height, forKey: "height")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        widthValue.text = String(userDefault.integer(forKey: "width"))
        heightValue.text = String(userDefault.integer(forKey: "height"))
        
        let toolBar = UIToolbar()
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissPicker))
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.sizeToFit()
        toolBar.setItems([spaceButton, cancelButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        widthValue.inputAccessoryView = toolBar
        heightValue.inputAccessoryView = toolBar
    }
}

class countryListTableViewController: UITableViewController{
    
    @IBOutlet var countryTable: UITableView!
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return countries.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let countryCell = tableView.dequeueReusableCell(withIdentifier: "country", for: indexPath) as! countryCell
        
        let name = allCountries[indexPath.row]
        
        for ctry in userDefault.array(forKey: "countriesArray")!{
            if name == (ctry as! String) {
                countryCell.accessoryType = .checkmark
                break
            }else{
                countryCell.accessoryType = .none
            }
        }
        
        countryCell.name.text = name
        
        return countryCell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        var arr = userDefault.array(forKey: "countriesArray")! as! [String]
        
        if arr[indexPath.row] == allCountries[indexPath.row]{
            arr[indexPath.row] = "null"
        }else{
            arr[indexPath.row] = allCountries[indexPath.row]
        }
        
        userDefault.set(arr, forKey: "countriesArray")
        
        tableView.reloadData()
        
    }
    
    @IBAction func selectChange(_ sender: UIBarButtonItem) {
        switch sender.tag {
        case -1:
            var arr = userDefault.array(forKey: "countriesArray")! as! [String]
            for i in 0..<arr.count{
                arr[i] = "null"
            }
            userDefault.set(arr, forKey: "countriesArray")
        case 0:
            userDefault.set(allCountries, forKey: "countriesArray")
        default:
            break
        }
        countryTable.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
}

class countryCell: UITableViewCell{
    @IBOutlet weak var name: UILabel!
}

class DownloadPhoto: NSObject {
    func get(url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            completion(data, response, error)
            }.resume()
    }
}

public extension UIDevice {
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
            
        case "iPhone3,1", "iPhone3,2", "iPhone3,3", "iPhone4,1":
            return "iPhone 4/s"
            
        case "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4", "iPhone6,1", "iPhone6,2", "iPhone8,4":
            return "iPhone 5/s/c/SE"
            
        case "iPhone7,2", "iPhone8,1", "iPhone9,1", "iPhone9,3", "iPhone10,1", "iPhone10,4":
            return "iPhone 6/s/7/8"
            
        case "iPhone7,1", "iPhone8,2", "iPhone9,2", "iPhone9,4", "iPhone10,2", "iPhone10,5":
            return "iPhone 6/s/7/8 Plus"
            
        case "iPhone10,3", "iPhone10,6":
            return "iPhone X"
            
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4", "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6", "iPad4,1", "iPad4,2", "iPad4,3", "iPad5,3", "iPad5,4", "iPad6,11", "iPad6,12", "iPad7,5", "iPad7,6", "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7", "iPad4,8", "iPad4,9", "iPad5,1", "iPad5,2", "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8", "iPad7,1", "iPad7,2", "iPad7,3", "iPad7,4":
            
            return "iPad"
            
        case "i386", "x86_64":
            return "Simulator"
            
        default:
            return identifier
        }
    }
    
}
