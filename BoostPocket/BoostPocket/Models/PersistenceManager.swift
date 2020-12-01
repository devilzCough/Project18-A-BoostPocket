//
//  PersistenceManager.swift
//  BoostPocket
//
//  Created by sihyung you on 2020/11/23.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import Foundation
import CoreData
import NetworkManager

protocol PersistenceManagable: AnyObject {
    var modelName: String { get }
    var persistentContainer: NSPersistentContainer { get }
    var context: NSManagedObjectContext { get }
    func createObject<T>(newObjectInfo: T) -> DataModelProtocol?
    func fetchAll<T: NSManagedObject>(request: NSFetchRequest<T>) -> [T]
    func fetch(_ request: NSFetchRequest<NSFetchRequestResult>) -> [Any]?
    func isExchangeRateOutdated(lastUpdated: Date) -> Bool
    func updateObject<T>(updatedObjectInfo: T) -> DataModelProtocol?
    func delete<T>(deletingObject: T) -> Bool
    func count<T: NSManagedObject>(request: NSFetchRequest<T>) -> Int?
    @discardableResult func saveContext() -> Bool
}

class PersistenceManager: PersistenceManagable {
    private weak var dataLoader: DataLoader?
    private(set) var modelName = "BoostPocket"
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)
        container.loadPersistentStores { (_, error) in
            if let error = error as NSError? {
                dump(error)
            }
        }
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return self.persistentContainer.viewContext
    }
    
    init(dataLoader: DataLoader) {
        self.dataLoader = dataLoader
    }
    
    // MARK: - Core Data Saving support
    
    @discardableResult
    func saveContext() -> Bool {
        if context.hasChanges {
            do {
                try context.save()
                return true
            } catch {
                let nserror = error as NSError
                print(nserror.localizedDescription)
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Core Data Creating support
    
    func createObject<T>(newObjectInfo: T) -> DataModelProtocol? {
        var createdObject: DataModelProtocol?
        
        if let newCountryInfo = newObjectInfo as? CountryInfo {
            createdObject = setupCountryInfo(countryInfo: newCountryInfo)
        } else if let newTravelInfo = newObjectInfo as? TravelInfo {
            createdObject = setupTravelInfo(travelInfo: newTravelInfo)
        }
        
        do {
            try self.context.save()
            return createdObject
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    private func setupCountryInfo(countryInfo: CountryInfo) -> Country? {
        guard let entity = NSEntityDescription.entity(forEntityName: Country.entityName, in: self.context) else { return nil }
        let newCountry = Country(entity: entity, insertInto: context)
        
        newCountry.name = countryInfo.name
        newCountry.lastUpdated = countryInfo.lastUpdated
        newCountry.flagImage = countryInfo.flagImage
        newCountry.exchangeRate = countryInfo.exchangeRate
        newCountry.currencyCode = countryInfo.currencyCode
        
        return newCountry
    }
    
    private func setupTravelInfo(travelInfo: TravelInfo) -> Travel? {
        guard let entity = NSEntityDescription.entity(forEntityName: Travel.entityName, in: self.context) else { return nil }
        let newTravel = Travel(entity: entity, insertInto: context)
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Country.entityName)
        fetchRequest.predicate = NSPredicate(format: "name == %@", travelInfo.countryName)
        
        guard let countries = fetch(fetchRequest) as? [Country], let fetchedCountry = countries.first else { return nil }
        
        newTravel.country = fetchedCountry
        newTravel.id = travelInfo.id
        newTravel.title = travelInfo.title
        newTravel.memo = travelInfo.memo
        newTravel.startDate = travelInfo.startDate
        newTravel.endDate = travelInfo.endDate
        newTravel.budget = travelInfo.budget
        newTravel.coverImage = travelInfo.coverImage
        
        // check if lastupdated is outdated
        if let lastUpdated = fetchedCountry.lastUpdated, isExchangeRateOutdated(lastUpdated: lastUpdated) {
            // if so, request exchange rate API again
            let url = "https://api.exchangeratesapi.io/latest?base=KRW"
            
            dataLoader?.requestExchangeRate(url: url) { [weak self] (result) in
                guard let currencyCode = fetchedCountry.currencyCode else { return }
                
                switch result {
                case .success(let data):
                    
                    let newExchangeRate = data.rates[currencyCode] ?? fetchedCountry.exchangeRate
                    let newLastUpdated = data.date.convertToDate()
                    newTravel.exchangeRate = newExchangeRate
                    
                    if let countryName = fetchedCountry.name,
                        let flagImage = fetchedCountry.flagImage,
                        let currencyCode = fetchedCountry.currencyCode,
                        self?.updateObject(updatedObjectInfo: CountryInfo(name: countryName, lastUpdated: newLastUpdated, flagImage: flagImage, exchangeRate: newExchangeRate, currencyCode: currencyCode)) != nil {
                        print("환율 정보 업데이트 성공")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    newTravel.exchangeRate = fetchedCountry.exchangeRate
                }
            }
            return newTravel
        } else {
            newTravel.exchangeRate = fetchedCountry.exchangeRate
            return newTravel
        }
    }
    
    func isExchangeRateOutdated(lastUpdated: Date) -> Bool {
        return !Calendar.current.isDateInToday(lastUpdated)
    }
    
    // MARK: - Core Data Retrieving support
    
    func fetchAll<T: NSManagedObject>(request: NSFetchRequest<T>) -> [T] {
        if T.self == Country.self {
            let nameSort = NSSortDescriptor(key: "name", ascending: true)
            request.sortDescriptors = [nameSort]
        } else if T.self == Travel.self {
            let startDateSort = NSSortDescriptor(key: "startDate", ascending: true)
            request.sortDescriptors = [startDateSort]
        }
        
        do {
            let fetchedResult = try self.context.fetch(request)
            return fetchedResult
        } catch {
            return []
        }
    }
    
    func fetch(_ request: NSFetchRequest<NSFetchRequestResult>) -> [Any]? {
        do {
            let fetchResult = try self.context.fetch(request)
            return fetchResult
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Core Data Updating support
    
    func updateObject<T>(updatedObjectInfo: T) -> DataModelProtocol? {
        var updatedObject: DataModelProtocol?
        
        if let updatedTravelInfo = updatedObjectInfo as? TravelInfo, let updatedTravel =  updateTravel(travelInfo: updatedTravelInfo) {
            updatedObject = updatedTravel
        } else if let updatedCountryInfo = updatedObjectInfo as? CountryInfo, let updatedCountry = updateCountry(countryInfo: updatedCountryInfo) {
            updatedObject = updatedCountry
        }
        
        do {
            try self.context.save()
            return updatedObject
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    private func updateTravel(travelInfo: TravelInfo) -> Travel? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Travel.entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", travelInfo.id as CVarArg)
        
        do {
            let anys = try self.context.fetch(fetchRequest)
            let objectUpdate = anys[0] as? NSManagedObject
            
            objectUpdate?.setValue(travelInfo.title, forKey: "title")
            objectUpdate?.setValue(travelInfo.memo, forKey: "memo")
            objectUpdate?.setValue(travelInfo.startDate, forKey: "startDate")
            objectUpdate?.setValue(travelInfo.endDate, forKey: "endDate")
            objectUpdate?.setValue(travelInfo.budget, forKey: "budget")
            objectUpdate?.setValue(travelInfo.coverImage, forKey: "coverImage")
            
            try self.context.save()
            
            let travels = fetch(fetchRequest) as? [Travel]
            let updatedTravel = travels?.first
            
            return updatedTravel
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    private func updateCountry(countryInfo: CountryInfo) -> Country? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Country.entityName)
        fetchRequest.predicate = NSPredicate(format: "name == %@", countryInfo.name)
        
        do {
            let anys = try self.context.fetch(fetchRequest)
            let objectUpdate = anys[0] as? NSManagedObject
            
            objectUpdate?.setValue(countryInfo.lastUpdated, forKey: "lastUpdated")
            objectUpdate?.setValue(countryInfo.exchangeRate, forKey: "exchangeRate")
            
            try self.context.save()
            
            let countries = fetch(fetchRequest) as? [Country]
            let updatedCountry = countries?.first
            return updatedCountry
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: - Core Data Deleting support
    
    func delete<T>(deletingObject: T) -> Bool {
        
        if let travelObject = deletingObject as? Travel {
            self.context.delete(travelObject)
        } else if let countryObject = deletingObject as? Country {
            self.context.delete(countryObject)
        }
        
        do {
            try context.save()
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Core Data Counting support
    
    func count<T: NSManagedObject>(request: NSFetchRequest<T>) -> Int? {
        do {
            let count = try self.context.count(for: request)
            return count
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}
