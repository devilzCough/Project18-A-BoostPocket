//
//  TravelProvider.swift
//  BoostPocket
//
//  Created by 이승진 on 2020/11/25.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import Foundation

protocol TravelProvidable: AnyObject {
    var travels: [Travel] { get }
    func createTravel(countryName: String) -> Travel?
    func fetchTravels() -> [Travel]
    func deleteTravel(id: UUID) -> Bool
    func updateTravel(updatedTravelInfo: TravelInfo) -> Travel?
}

class TravelProvider: TravelProvidable {
    private weak var persistenceManager: PersistenceManagable?
    var travels: [Travel] = []
    
    init(persistenceManager: PersistenceManagable) {
        self.persistenceManager = persistenceManager
    }
    
    func createTravel(countryName: String) -> Travel? {
        let newTravelInfo = TravelInfo(countryName: countryName, id: UUID(), title: countryName, memo: "", startDate: Date(), endDate: Date(), coverImage: Data(), budget: Double(), exchangeRate: Double())
        
        guard let createdObject = persistenceManager?.createObject(newObjectInfo: newTravelInfo),
            let createdTravel = createdObject as? Travel
            else { return nil }
        
        travels.append(createdTravel)
        return createdTravel
    }
    
    func fetchTravels() -> [Travel] {
        guard let persistenceManager = persistenceManager else { return [] }
        travels = persistenceManager.fetchAll(request: Travel.fetchRequest())
        
        return travels
    }
    
    func updateTravel(updatedTravelInfo: TravelInfo) -> Travel? {
        guard let persistenceManager = persistenceManager,
            let updatedTravel = persistenceManager.updateObject(updatedObjectInfo: updatedTravelInfo) as? Travel,
            let indexToUpdate = travels.indices.filter({ travels[$0].id == updatedTravel.id }).first
            else { return nil }
        
        self.travels[indexToUpdate] = updatedTravel
        return updatedTravel
    }
    
    func deleteTravel(id: UUID) -> Bool {
        guard let indexToDelete = travels.indices.filter({ travels[$0].id == id }).first,
              let persistenceManager = persistenceManager else { return false }
        
        let deletingTravel = travels[indexToDelete]
        if persistenceManager.delete(deletingObject: deletingTravel) {
            self.travels.remove(at: indexToDelete)
            return true
        } else {
            return false
        }
    }
}
