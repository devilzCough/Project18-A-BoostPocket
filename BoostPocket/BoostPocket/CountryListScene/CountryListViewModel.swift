//
//  CountryListViewModel.swift
//  BoostPocket
//
//  Created by 송주 on 2020/11/23.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import Foundation

protocol CountryListPresentable: AnyObject {
    var countries: [CountryItemViewModel] { get }
    var didFetch: (([CountryItemViewModel]) -> Void)? { get set }
    
    func needFetchItems()
    @discardableResult func createCountry(name: String, lastUpdated: Date, flagImage: Data, exchangeRate: Double, currencyCode: String) -> CountryItemViewModel?
    func cellForItemAt(path: IndexPath) -> CountryItemViewModel
    func numberOfItem() -> Int
}

class CountryListViewModel: CountryListPresentable {
    var didFetch: (([CountryItemViewModel]) -> Void)?
    var countries: [CountryItemViewModel] = []
    private weak var countryProvider: CountryProvidable?
    
    init(countryProvider: CountryProvidable) {
        self.countryProvider = countryProvider
    }
    
    func needFetchItems() {
        guard let fetchedCountries = countryProvider?.fetchCountries() else { return }
        
        fetchedCountries.forEach { country in
            self.countries.append(CountryItemViewModel(country: country))
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.didFetch?(self?.countries ?? [])
        }
    }
    
    @discardableResult
    func createCountry(name: String, lastUpdated: Date, flagImage: Data, exchangeRate: Double, currencyCode: String) -> CountryItemViewModel? {
        guard let createdCountry = countryProvider?.createCountry(name: name, lastUpdated: lastUpdated, flagImage: flagImage, exchangeRate: exchangeRate, currencyCode: currencyCode) else { return nil }
        let createdCountryItemViewModel = CountryItemViewModel(country: createdCountry)
        countries.append(createdCountryItemViewModel)
        return createdCountryItemViewModel
    }
    
    func cellForItemAt(path: IndexPath) -> CountryItemViewModel {
        return countries[path.row]
    }
    
    func numberOfItem() -> Int {
        return countries.count
    }
}
