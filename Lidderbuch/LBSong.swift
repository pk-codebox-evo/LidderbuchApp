//
//  LBSong.swift
//  Lidderbuch
//
//  Copyright (c) 2015 Fränz Friederes <fraenz@frieder.es>
//  Licensed under the MIT license.
//

import Foundation
import CoreSpotlight
import MobileCoreServices

class LBSong: NSObject, NSUserActivityDelegate
{
    var id: Int!
    var name: String!
    var language: String!
    var url: NSURL!
    var category: String!
    var position: Int!
    var paragraphs: [LBParagraph]!
    var updateTime: NSDate!
    
    var bookmarked: Bool = false
    var views: Int = 0
    var viewTime: NSDate?
    
    var number: Int?
    var way: String?
    var year: Int?
    var lyricsAuthor: String?
    var melodyAuthor: String?
    
    override var description: String {
        return "\(id): \(name)"
    }
    
    var preview: String {
        // grab the two first lines of a song
        // if a paragraph has only one line, the next one will be included too
        var preview = "", lines = 0, i = -1
        while (++i < paragraphs.count && lines < 2) {
            let paragraphLines = paragraphs[i].content.componentsSeparatedByString("\n")
            var j = -1
            while (++j < paragraphLines.count && lines < 2) {
                preview += (lines > 0 ? "\n" : "") + paragraphLines[j]
                lines++
            }
        }
        return preview
    }
    
    var detail: String
    {
        // glue together song details if available
        var parts = [String]()
        
        if let number = self.number {
            parts.append(NSLocalizedString("No", comment: "Song detail") + " \(number)")
        }
        
        if let way = self.way {
            parts.append(NSLocalizedString("Weis", comment: "Song detail") + ": \(way)")
        }
        
        if self.lyricsAuthor != nil && self.lyricsAuthor == self.melodyAuthor
        {
            parts.append(NSLocalizedString("Text a Melodie", comment: "Song detail") + ": \(self.lyricsAuthor!)")
        }
        else
        {
            if let lyricsAuthor = self.lyricsAuthor {
                parts.append(NSLocalizedString("Text", comment: "Song detail") + ": \(lyricsAuthor)")
            }
            
            if let melodyAuthor = self.melodyAuthor {
                parts.append(NSLocalizedString("Melodie", comment: "Song detail") + ": \(melodyAuthor)")
            }
        }
        
        if let year = self.year {
            parts.append(String(year))
        }
        
        return parts.joinWithSeparator(" · ")
    }
    
    init?(json: AnyObject)
    {
        super.init()
        
        if let songJson = json as? [String: AnyObject]
        {
            // retrieve required attributes
            if let
                id = songJson["id"] as? Int,
                name = songJson["name"] as? String,
                language = songJson["language"] as? String,
                category = songJson["category"] as? String,
                position = songJson["position"] as? Int,
                updateTimestamp = songJson["update_time"] as? Int,
                paragraphsJson = songJson["paragraphs"] as? [AnyObject],
            
                urlString = songJson["url"] as? String,
                url = NSURL(string: urlString)
            {
                // basic attributes
                self.id = id
                self.name = name
                self.language = language
                self.url = url
                self.category = category
                self.position = position
                self.updateTime = NSDate(timeIntervalSince1970: Double(updateTimestamp))
                
                // paragraphs
                self.paragraphs = [LBParagraph]()
                for paragraphJson in paragraphsJson {
                    if let paragraph = LBParagraph(json: paragraphJson) {
                        self.paragraphs.append(paragraph)
                    }
                }
                
                // optional attributes
                self.number = songJson["number"] as? Int
                self.way = songJson["way"] as? String
                self.year = songJson["year"] as? Int
                self.lyricsAuthor = songJson["lyrics_author"] as? String
                self.melodyAuthor = songJson["melody_author"] as? String
                
                if songJson["bookmarked"] as? Bool == true {
                    self.bookmarked = true
                }
                
                if let views = songJson["views"] as? Int {
                    self.views = views
                }
                
                if let viewTimestamp = songJson["viewTime"] as? Int {
                    self.viewTime = NSDate(timeIntervalSince1970: Double(viewTimestamp))
                }
                
                return
            }
        }
        
        return nil
    }
    
    func json() -> [String: AnyObject]
    {
        // prepare paragraphs json object
        var paragraphsJsonObject = [AnyObject]()
        
        for paragraph in paragraphs {
            paragraphsJsonObject.append(paragraph.json())
        }
        
        // prepare json object
        let jsonObject: [String: AnyObject!] = [
            "id": id,
            "name": name,
            "language": language,
            "url": url.absoluteString,
            "category": category,
            "position": position,
            "update_time": Int(updateTime!.timeIntervalSince1970),
            
            "paragraphs": paragraphsJsonObject,
            
            // meta
            "bookmarked": bookmarked,
            "views": views,
            "viewTime": (viewTime != nil ? Int(viewTime!.timeIntervalSince1970) : NSNull()),
            
            // optional details
            "number": (number != nil ? number! : NSNull()),
            "way": (way != nil ? way! : NSNull()),
            "year": (year != nil ? year! : NSNull()),
            "lyrics_author": (lyricsAuthor != nil ? lyricsAuthor! : NSNull()),
            "melody_author": (melodyAuthor != nil ? melodyAuthor! : NSNull()),
        ]
        
        return jsonObject
    }
    
    override func isEqual(object: AnyObject?) -> Bool
    {
        if let song = object as? LBSong {
            return id == song.id
        }
        return false
    }
    
    private var lastSearchKeywords: String?
    private var lastSearchScore: Int?
    
    func search(keywords: String) -> Int
    {
        // retrieve cached result
        if lastSearchKeywords == keywords {
            return lastSearchScore!
        }
        
        // determin search score for given keywords
        var score = 0
        
        // search in meta data
        score += name.countOccurencesOfString(keywords)
        
        if let way = self.way {
            score += way.countOccurencesOfString(keywords)
        }
        
        if let lyricsAuthor = self.lyricsAuthor {
            score += lyricsAuthor.countOccurencesOfString(keywords)
        }
        
        if lyricsAuthor != melodyAuthor {
            if let melodyAuthor = self.melodyAuthor {
                score += melodyAuthor.countOccurencesOfString(keywords)
            }
        }
        
        // an occurence in meta data is 3x more important
        score *= 3
        
        // search score of paragraphs
        for paragraph in paragraphs {
            score += paragraph.search(keywords)
        }
        
        // cache search result
        lastSearchKeywords = keywords
        lastSearchScore = score
        
        return score
    }
    
    @available(iOS 9.0, *)
    func createUserActivity() -> NSUserActivity
    {
        // collect text content
        var text = ""
        for paragraph: LBParagraph in paragraphs {
            text += paragraph.content + "\n\n"
        }
        
        // collect meta
        let contentAttributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        contentAttributeSet.title = name
        contentAttributeSet.contentDescription = text
        contentAttributeSet.identifier = String(id)
        
        if let lyricsAuthor = lyricsAuthor {
            contentAttributeSet.lyricist = lyricsAuthor
        }
        
        if let melodyAuthor = melodyAuthor {
            contentAttributeSet.composer = melodyAuthor
        }
        
        // create activity
        let activity = NSUserActivity(activityType: LBVariables.viewSongUserActivityType)
        
        activity.title = name
        activity.webpageURL = url
        activity.userInfo = ["id": id]
        activity.delegate = self
        activity.needsSave = true
        activity.requiredUserInfoKeys = Set(["id"])
        activity.contentAttributeSet = contentAttributeSet
        activity.eligibleForSearch = true
        activity.eligibleForPublicIndexing = true
        activity.eligibleForHandoff = true
        
        return activity
    }
    
    func userActivityWillSave(userActivity: NSUserActivity)
    {
        userActivity.userInfo = ["id": id]
    }
}