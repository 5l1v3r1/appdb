//
//  SuggestionsWhileTyping.swift
//  appdb
//
//  Created by ned on 16/10/2017.
//  Copyright © 2017 ned. All rights reserved.
//

import Cartography
import RealmSwift
import ObjectMapper

protocol SearcherDelegate: class {
    func didClickSuggestion(_ text: String)
}

class SuggestionsWhileTyping: UITableViewController, UISearchResultsUpdating {
    
    var searcherDelegate: SearcherDelegate?
    
    var text: String = ""
    var results: [String] = []
    
    var type: ItemType = .ios
    
    var matchingColor: UIColor {
        return Themes.isNight ? .white : .black
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
        tableView.theme_backgroundColor = Color.veryVeryLightGray
        view.theme_backgroundColor = Color.veryVeryLightGray
        tableView.theme_separatorColor = Color.borderColor
        tableView.register(SearchSuggestionCell.self, forCellReuseIdentifier: "suggestion")
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = 40~~35
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        if text.count > 1 {
            self.text = text
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.reload), object: nil)
            self.perform(#selector(self.reload), with: nil, afterDelay: 0.15)
        } else {
            if results.isEmpty {
                results = []
                tableView.reloadData()
            }
        }
    }
    
    @objc func reload() {
        API.fastSearch(type: self.type, query: self.text, maxResults: 7, success: { results in
            self.results = results
            self.tableView.reloadData()
        })
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "suggestion", for: indexPath) as! SearchSuggestionCell
        if results.indices.contains(indexPath.row) {
            var result = results[indexPath.row]
            while result.hasPrefix(" ") { result = String(result.dropFirst()) }
            cell.label.attributedText = attributedText(withString: result, matchString: text, font: cell.label.font)
        }
       return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searcherDelegate?.didClickSuggestion(results[indexPath.row])
    }
    
    fileprivate func attributedText(withString string: String, matchString: String, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string, attributes: [NSAttributedString.Key.font: font])
        let boldFontAttribute: [NSAttributedString.Key: Any] = [NSAttributedString.Key.foregroundColor: matchingColor]
        let range = (string as NSString).range(of: matchString, options: .caseInsensitive)
        attributedString.addAttributes(boldFontAttribute, range: range)
        return attributedString
    }
}

class SearchSuggestionCell: UITableViewCell {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    lazy var bgColorView: UIView = {
        let view = UIView()
        view.theme_backgroundColor = Color.cellSelectionColor
        return view
    }()
    
    lazy var searchImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = #imageLiteral(resourceName: "Search").withRenderingMode(.alwaysTemplate)
        imageView.theme_tintColor = ["#c6c6c6", "#7c7c7c"]
        return imageView
    }()
    
    lazy var label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: (17~~16))
        label.numberOfLines = 1
        label.theme_textColor = ["#777777", "#828282"]
        label.makeDynamicFont()
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.theme_backgroundColor = Color.veryVeryLightGray
        theme_backgroundColor = Color.veryVeryLightGray
        textLabel?.theme_textColor = Color.title
        selectedBackgroundView = bgColorView
        
        contentView.addSubview(label)
        contentView.addSubview(searchImageView)
        
        constrain(label, searchImageView) { label, image in
            
            image.height == 20
            image.width == 30
            
            image.left == image.superview!.layoutMarginsGuide.left
            image.centerY == image.superview!.centerY
            
            label.left == image.right + (10~~7)
            label.right == label.superview!.layoutMarginsGuide.right
            label.centerY == image.centerY
        }
        
    }
}
