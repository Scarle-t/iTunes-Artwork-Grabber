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
        let key = keys[indexPath.row]
        let img = imgs[key]
        let alert = UIAlertController(title: key, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Save to Camera Roll", style: .default, handler: { _ in
            UIImageWriteToSavedPhotosAlbum(img!, nil, nil, nil)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
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
        for ctry in countries{
            if ctry.value == countryList.text{
                getJSON(query: query.text!, code: ctry.key)
                break
            }else{
                continue
            }
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
                    guard let imgData = data, error == nil else { return }
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
