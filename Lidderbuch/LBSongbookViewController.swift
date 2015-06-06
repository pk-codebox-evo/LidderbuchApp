//
//  LBSongbookViewController.swift
//  Lidderbuch
//
//  Created by Fränz Friederes on 13/05/15.
//  Copyright (c) 2015 ACEL. All rights reserved.
//

import UIKit

class LBSongbookViewController: LBViewController,
    LBSongbookDelegate,
    LBSongViewControllerDelegate,
    UINavigationControllerDelegate,
    UITableViewDataSource,
    UITableViewDelegate,
    UITextFieldDelegate
{
    var songbook: LBSongbook!
    
    var searchingInBackground = false
    var searchSongs: [LBSong]? {
        didSet {
            headerBar.disableVerticalTranslation = (searchSongs != nil)
            tableView.reloadData()
        }
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchTextField: UITextField!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        songbook = LBSongbook()
        songbook.delegate = self
        
        tableView.estimatedRowHeight = 100.0
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        
        let selectedRowIndexPath = tableView.indexPathForSelectedRow()
        
        UIView.setAnimationsEnabled(false)
        
        tableView.reloadData()
        
        // preserve selected row
        tableView.selectRowAtIndexPath(selectedRowIndexPath, animated: false, scrollPosition: .None)
        
        UIView.setAnimationsEnabled(true)
    }
    
    func songbookDidUpdate(songbook: LBSongbook)
    {
        if searchSongs != nil {
            search()
        }
    
        let selectedRowIndexPath = tableView.indexPathForSelectedRow()
        tableView.reloadData()
        
        // preserve selected row (if not in bookmark category)
        if selectedRowIndexPath?.section != 0 {
            tableView.selectRowAtIndexPath(selectedRowIndexPath, animated: false, scrollPosition: .None)
        }
    }
    
    func songViewController(songViewController: LBSongViewController, songDidChange song: LBSong)
    {
        songbook.integrateSong(song, preserveMeta: false, propagate: true)
    }
    
    func songForRowAtIndexPath(indexPath: NSIndexPath) -> LBSong?
    {
        if searchSongs != nil {
            return searchSongs![indexPath.row]
        } else if indexPath.row > 0 {
            let category = songbook.categories[indexPath.section]
            return songbook.categorySongs[category]![indexPath.row - 1]
        }
        
        return nil
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        if searchSongs != nil {
            return 1
        }
        
        return songbook.categories.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        if searchSongs != nil {
            return searchSongs!.count
        }
        
        let category = songbook.categories[section]
        let count = songbook.categorySongs[category]!.count
        
        if count == 0 {
            return 0
        }
        
        return count + 1
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        return UITableViewAutomaticDimension
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        if searchSongs == nil && indexPath.row == 0
        {
            // category cell
            let cell = tableView.dequeueReusableCellWithIdentifier("CategoryCell", forIndexPath: indexPath) as! LBCategoryTableViewCell
        
            cell.category = songbook.categories[indexPath.section]
            
            return cell
        }
        else
        {
            // song cell
            let cell = tableView.dequeueReusableCellWithIdentifier("SongCell", forIndexPath: indexPath) as! LBSongTableViewCell
            
            cell.song = songForRowAtIndexPath(indexPath)
            
            return cell
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if songForRowAtIndexPath(indexPath) != nil {
            searchTextField.resignFirstResponder()
            performSegueWithIdentifier("ShowSong", sender: self)
        } else {
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if (segue.identifier == "ShowSong")
        {
            // inject selected song into song view controller
            if let songViewController = segue.destinationViewController as? LBSongViewController {
                if let selectedIndexPath = tableView.indexPathForSelectedRow() {
                    songViewController.delegate = self
                    songViewController.song = songForRowAtIndexPath(selectedIndexPath)!
                }
            }
        }
    }
    
    func navigationController(navigationController: UINavigationController, didShowViewController viewController: UIViewController, animated: Bool) {
        if viewController === self {
            if let selectedRowIndexPath = tableView.indexPathForSelectedRow() {
                tableView.deselectRowAtIndexPath(selectedRowIndexPath, animated: animated)
            }
        }
    }
    
    func search()
    {
        // cancel if already searching in background
        if !searchingInBackground
        {
            let keywords = searchTextField.text
            
            searchingInBackground = true
            
            songbook.search(keywords, callback: {
                (songs, keywords) in
                
                self.searchingInBackground = false
                
                if (self.searchSongs != nil)
                {
                    // show search results
                    self.searchSongs = songs
                    
                    // scroll to top
                    self.scrollView.contentOffset = CGPoint(x: 0.0, y: -self.scrollView.contentInset.top)
                    
                    // search again if keywords have been changed
                    if keywords != self.searchTextField.text {
                        self.search()
                    }
                }
            })
        }
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        searchSongs = [LBSong]()
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        if searchTextField.text == "" {
            searchSongs = nil
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()
        return true
    }
    
    override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        searchTextField.resignFirstResponder()
    }
    
    @IBAction func handleSearchTextFieldChange(textField: UITextField) {
        search()
    }
}
