//
//  ViewController.swift
//  BoostPocket
//
//  Created by sihyung you on 2020/11/19.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import UIKit

enum Layout {
    case defaultLayout
    case squareLayout
    case rectangleLayout
    case hamburgerLayout
}

class TravelListViewController: UIViewController {
    typealias DataSource = UICollectionViewDiffableDataSource<TravelSection, TravelItemViewModel>
    typealias SnapShot = NSDiffableDataSourceSnapshot<TravelSection, TravelItemViewModel>
    
    var layout: Layout = .defaultLayout
    lazy var dataSource: DataSource = configureDataSource()
    var travelListViewModel: TravelListPresentable? {
        didSet {
            
            travelListViewModel?.didFetch = { [weak self] fetchedTravels in
                self?.travelListCollectionView.reloadData()
                self?.applySnapShot(with: fetchedTravels)
            }
        }
    }
    
    @IBOutlet weak var travelListCollectionView: UICollectionView!
    @IBOutlet var layoutButtons: [UIButton]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        travelListViewModel?.needFetchItems()
    }
    
    private func configureCollectionView() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.minimumInteritemSpacing = 0
        travelListCollectionView.setCollectionViewLayout(flowLayout, animated: true)
        
        travelListCollectionView.delegate = self
        travelListCollectionView.register(TravelCell.getNib(), forCellWithReuseIdentifier: TravelCell.identifier)
        travelListCollectionView.register(TravelHeaderCell.getNib(), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TravelHeaderCell.identifier)
    }
    
    private func configureDataSource() -> DataSource {
        let dataSource = DataSource(collectionView: travelListCollectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TravelCell.identifier, for: indexPath) as? TravelCell else { return UICollectionViewCell() }
            cell.configure(with: item)
            return cell
        }
        
        dataSource.supplementaryViewProvider = { (collectionView, kind, indexPath) in
            guard let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TravelHeaderCell.identifier, for: indexPath) as? TravelHeaderCell else { return UICollectionReusableView() }
            
            let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
            // TODO: 여행 개수 찾는 방법 고민해보기..
            // let travelNumber = dataSource.snapshot().numberOfItems
            sectionHeader.configure(with: section, numberOfTravel: self.travelListViewModel?.travels.count ?? 0)
            
            return sectionHeader
        }
        
        return dataSource
    }
    
    func applySnapShot(with travels: [TravelItemViewModel]) {
        var snapShot = SnapShot()
        snapShot.appendSections([.current, .past, .upcoming])
        travels.forEach { travel in
            let section = getTravelSection(with: travel)
            snapShot.appendItems([travel], toSection: section)
        }
        
        // TODO: - reloadData 없이 구현하는 방법 고민하기
        dataSource.apply(snapShot, animatingDifferences: true)
    }
    
    func getTravelSection(with travel: TravelItemViewModel) -> TravelSection {
        let today = Date()
        guard let startDate = travel.startDate, let endDate = travel.endDate else { return .upcoming }
        
        if endDate < today {
            return .past
        } else if startDate > today {
            return .upcoming
        }
        return .current
    }
    
    private func resetAlphaOfLayoutButtons() {
        layoutButtons.forEach { $0.alpha = 0.5 }
    }
    
    @IBAction func layoutButtonTapped(_ sender: UIButton) {
        resetAlphaOfLayoutButtons()
        sender.alpha = 1
        
        let index = layoutButtons.firstIndex(of: sender)
        switch index {
        case 0:
            layout = .defaultLayout
        case 1:
            layout = .squareLayout
        case 2:
            layout = .rectangleLayout
        default:
            layout = .hamburgerLayout
        }
        applySnapShot(with: travelListViewModel?.travels ?? [])
    }
    
    @IBAction func newTravelButtonTapped(_ sender: Any) {
        let countryListVC = CountryListViewController.init(nibName: "CountryListViewController", bundle: nil)
        
        guard let countryListViewModel = travelListViewModel?.createCountryListViewModel() else { return }
        
        countryListVC.countryListViewModel = countryListViewModel
        countryListVC.doneButtonHandler = { (selectedCountry) in
            dump(selectedCountry)
            self.travelListViewModel?.createTravel(countryName: selectedCountry.name)
            
            /*
             // 2주차 데모 내용에서 제외
             let storyboard = UIStoryboard(name: "TravelDetail", bundle: nil)
             guard let tabBarVC = storyboard.instantiateViewController(withIdentifier: TravelDetailTabbarController.identifier) as? TravelDetailTabbarController else { return }
             
             self.navigationController?.pushViewController(tabBarVC, animated: true)
             */
        }
        
        let navigationController = UINavigationController(rootViewController: countryListVC)
        self.present(navigationController, animated: true, completion: nil)
    }
}

extension TravelListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat
        var height: CGFloat
        
        switch layout {
        case .defaultLayout:
            width = self.view.bounds.width * 0.9
            height = width
        case .squareLayout:
            width = (collectionView.bounds.width - 15 * 3) / 2
            height = width
        case .rectangleLayout:
            width = self.view.bounds.width * 0.8
            height = 100
        case .hamburgerLayout:
            width = self.view.bounds.width * 0.8
            height = 100
        }
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if layout == .squareLayout {
            return UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        }
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

extension TravelListViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let selectedTravelViewModel = dataSource.itemIdentifier(for: indexPath) else { return }
        
        let storyboard = UIStoryboard(name: "TravelDetail", bundle: nil)
        guard let tabBarVC = storyboard.instantiateViewController(withIdentifier: TravelDetailTabbarController.identifier) as? TravelDetailTabbarController,
            let profileVC = tabBarVC.viewControllers?[0] as? TravelProfileViewController
            else { return }
        
        tabBarVC.setupChildViewControllers(with: selectedTravelViewModel)
        profileVC.profileDelegate = self
        
        self.navigationController?.pushViewController(tabBarVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        let section = dataSource.snapshot().sectionIdentifiers[section]
        if section == .current {
            return CGSize(width: self.view.bounds.width, height: 100)
        }
        return CGSize(width: self.view.bounds.width, height: 50)
        
    }
}

extension TravelListViewController: TravelProfileDelegate {
    func deleteTravel(id: UUID?) {
        if let travelListViewModel = travelListViewModel,
            let deletingId = id,
            travelListViewModel.deleteTravel(id: deletingId) {
            print("여행을 삭제했습니다.")
        } else {
            // TODO: - listVM, id, delete 과정 중 문제가 생겨 실패 시 사용자에게 noti
            print("여행 삭제에 실패했습니다.")
        }
    }
    
    func updateTravel(id: UUID? = nil, newTitle: String? = nil, newMemo: String?, newStartDate: Date? = nil, newEndDate: Date? = nil, newCoverImage: Data? = nil, newBudget: Double? = nil, newExchangeRate: Double? = nil) {
        if let travelListViewModel = travelListViewModel,
            let updatingId = id,
            let updatingTravel = travelListViewModel.travels.filter({ $0.id == updatingId }).first,
            let countryName = updatingTravel.countryName,
            let title = updatingTravel.title,
            let coverImage = updatingTravel.coverImage,
            
            travelListViewModel.updateTravel(countryName: countryName, id: updatingId, title: newTitle ?? title, memo: newMemo, startDate: newStartDate, endDate: newEndDate, coverImage: newCoverImage ?? coverImage, budget: newBudget ?? updatingTravel.budget, exchangeRate: newExchangeRate ?? updatingTravel.exchangeRate) {
            print("여행 정보 업데이트 성공")
        } else {
            print("여행 정보 업데이트 실패")
        }
    }
}
