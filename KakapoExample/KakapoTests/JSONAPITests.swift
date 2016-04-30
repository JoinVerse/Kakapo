//
//  JSONAPITests.swift
//  KakapoExample
//
//  Created by Alex Manzella on 28/04/16.
//  Copyright © 2016 devlucky. All rights reserved.
//

import Foundation
import Quick
import Nimble
import SwiftyJSON
@testable import Kakapo

struct Policy<T>: JSONAPIEntity {
    let id: String
    let policy: PropertyPolicy<T>
}

class JSONAPISpec: QuickSpec {
    
    struct Dog: JSONAPIEntity {
        let id: String
        let name: String
        var chasingCat: Cat?
    }
    
    struct Cat: JSONAPIEntity {
        let id: String
        let name: String
    }
    
    struct User: JSONAPIEntity {
        let id: String
        let name: String
        let dog: Dog
        let cats: [Cat]
    }
    
    struct Post: JSONAPIEntity {
        let id: String
        let relatedPostIds: [Int]
    }
    
    struct CustomPost: JSONAPIEntity, CustomSerializable {
        let id: String
        let title: String
        
        func customSerialize() -> AnyObject {
            return ["foo": "bar"]
        }
    }
    
    override func spec() {
        
        let cats = [Cat(id: "33", name: "Stancho"), Cat(id: "44", name: "Hez")]
        let dog = Dog(id: "22", name: "Joan", chasingCat: cats[0])
        let user = User(id: "11", name: "Alex", dog: dog, cats: cats)
        
        func json(object: Serializable) -> JSON {
            return JSON(object.serialize()!)
        }
        
        describe("JSON API Serialzier") {
            it("should serialize data") {
                let object = json(JSONAPISerializer(user))
                let data = object["data"].dictionaryValue
                expect(data.count).toNot(equal(0))
            }
            
            it("should serialize data from Array") {
                let object = json(JSONAPISerializer([user]))
                let data = object["data"].arrayValue
                expect(data.count).toNot(equal(0))
            }
        }
        
        describe("JSON API Entity Serialization") {
            
            it("should serialize the attributes") {
                let object = json(user)
                let attributes = object["attributes"]
                expect(attributes["id"].string).to(beNil())
                expect(attributes["name"].stringValue).to(equal("Alex"))
                expect(attributes.dictionaryValue.count).to(equal(1))
            }
            
            it("should serialzie the id") {
                let object = json(user)
                expect(object["id"].stringValue).to(equal("11"))
            }
            
            it("should serialzie the type") {
                let object = json(user)
                expect(object["type"].stringValue).to(equal("user"))
            }
            
            it("should serialzie an arrays of non-JSONAPIEntities as an attribute") {
                let object = json(Post(id: "11", relatedPostIds: [1, 2, 3]))
                let relatedPostIds = object["attributes"]["relatedPostIds"].arrayValue
                expect(relatedPostIds.count).to(equal(3))
                expect(relatedPostIds[0]).to(equal(1))
                expect(relatedPostIds[1]).to(equal(2))
                expect(relatedPostIds[2]).to(equal(3))
            }
            
            it("should serialzie an array of JSONAPIEntities") {
                let objects = json([user, user]).arrayValue
                for object in objects {
                    expect(object["attributes"]["name"].stringValue).to(equal("Alex"))
                }
                
                expect(objects.count).to(equal(2))
            }
            
            it("should only serialzie actual attributes into attributes") {
                let lonelyMax = User(id: "11", name: "Max", dog: dog, cats: [])
                let object = json(lonelyMax)
                let attributes = object["attributes"].dictionaryValue
                expect(attributes.count).to(equal(1)) // only name should be here, no id, no cats
                expect(attributes["name"]).to(equal("Max"))
                expect(attributes["cats"]).to(beNil())
                expect(attributes["id"]).to(beNil())
            }
            
            it("should fail to serialize CustomSerializable entities") {
                // TODO: discuss because this might be unexpected
                let object = json(CustomPost(id: "123", title: "Test"))
                expect(object["id"].string).toNot(beNil())
                expect(object["foo"].string).to(beNil())
            }
        }
        
        describe("JSON API Entity relationship serialization") {
            it("should serialzie the relationships when they are single JSONAPIEntities") {
                let object = json(user)
                let dog = object["relationships"]["dog"]["data"]
                expect(dog.dictionary).toNot(beNil())
                expect(dog["id"].stringValue).to(equal("22"))
                expect(dog["type"].stringValue).to(equal("dog"))
            }
            
            it("should serialzie the relationships when they are arrays of JSONAPIEntities") {
                let object = json(user)
                let cats = object["relationships"]["cats"]["data"].array!
                expect(cats.count).to(equal(2))
                expect(cats[0]["id"].stringValue).to(equal("33"))
                expect(cats[0]["type"].stringValue).to(equal("cat"))
                expect(cats[1]["id"].stringValue).to(equal("44"))
                expect(cats[1]["type"].stringValue).to(equal("cat"))
            }
            
            it("should not serialzie relationships of relationships") {
                let object = json(user)
                let dogData = object["relationships"]["dog"]["data"].dictionary
                expect(dogData).toNot(beNil())
                expect(dogData?["relationships"]).to(beNil())
            }
            
            it("should not serialzie attributes of relationships") {
                let object = json(user)
                let dogData = object["relationships"]["dog"]["data"].dictionary
                expect(dogData).toNot(beNil())
                expect(dogData?["attributes"]).to(beNil())
            }
            
            it("should not serialzie nil relationships") {
                let object = json(dog)
                let cat = object["relationships"].dictionaryValue
                expect(cat["chasingCat"]).to(beNil())
            }
            
            it("should serialzie the relationships even when an array is empty") {
                let lonelyMax = User(id: "11", name: "Max", dog: dog, cats: [])
                let object = json(lonelyMax)
                let cats = object["relationships"]["cats"].dictionary!
                expect(cats.count).to(equal(1))
                let dataArray = cats["data"]
                expect(dataArray).toNot(beNil())
                expect(dataArray?.count).to(equal(0))
            }
        }
        
        
        describe("JSON API Entity with PropertyPolicies") {
            it("should handle PropertyPolicies.None") {
                let object = json(Policy<Int>(id: "12", policy: .None))
                let attributes = object["attributes"].dictionaryObject
                expect(attributes).to(beNil())

            }
            
            it("should handle PropertyPolicies.Null") {
                let object = json(Policy<Int>(id: "12", policy: .Null))
                let attributes = object["attributes"].dictionaryObject!
                expect(attributes["policy"] as? NSNull).toNot(beNil())
            }
            
            it("should handle PropertyPolicies.Some(T)") {
                let object = json(Policy(id: "12", policy: .Some(123)))
                let attributes = object["attributes"].dictionaryValue
                expect(attributes["policy"]?.intValue).to(equal(123))
            }
            
            it("should handle PropertyPolicy as releantionships when the associated type conforms to JSONAPIEntity") {
                let object = json(Policy(id: "12", policy: .Some(user)))
                let data = object["relationships"]["policy"]["data"].dictionaryValue
                expect(data["type"]!.stringValue).to(equal("user"))
            }
            
            it("should handle PropertyPolicy as releantionships when the associated type is an array of JSONAPIEntity") {
                let object = json(Policy(id: "12", policy: .Some([user])))
                let data = object["relationships"]["policy"]["data"].arrayValue
                expect(data[0]["type"].stringValue).to(equal("user"))
            }
            
            it("should handle PropertyPolicy as releantionships when the associated type is JSONAPIEntity but .Null") {
                let object = json(Policy<User>(id: "12", policy: .Null))
                let data = object["relationships"]["policy"].dictionaryObject!["data"] as? [String: AnyObject]
                expect(data).toNot(beNil())
                expect(data?.count).to(equal(0))
            }
            
            it("should exclude PropertyPolicy as releantionships when the associated type is JSONAPIEntity but .None") {
                let object = json(Policy<User>(id: "12", policy: .None))
                let relationships = object["relationships"].dictionary
                expect(relationships).to(beNil())
            }
        }
    }
}