//
//  HistoryListViewController.swift
//  BoostPocket
//
//  Created by 송주 on 2020/12/02.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import UIKit

class HistoryListViewController: UIViewController {
    
    typealias DataSource = UITableViewDiffableDataSource<HistoryListSectionHeader, HistoryItemViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<HistoryListSectionHeader, HistoryItemViewModel>
    
    @IBOutlet weak var historyListTableView: UITableView!
    @IBOutlet weak var dayStackView: UIStackView!
    @IBOutlet weak var moneySegmentedControl: UISegmentedControl!
    
    weak var travelItemViewModel: HistoryListPresentable?
    
    // 필터 조건 저장
    private var isPrepareOnly: Bool? = false
    private var date: Date?
    private var isCard: Bool?
    
    private lazy var dataSource = configureDatasource()
    private lazy var headers = setupSection(with: travelItemViewModel?.histories ?? [])
    private lazy var refresher: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .clear
        refreshControl.addTarget(self, action: #selector(addHistory), for: .valueChanged)
        refreshControl.attributedTitle = NSAttributedString(string: "새 지출 입력하기")
        return refreshControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureSegmentedControl()
        setupDays(from: travelItemViewModel?.startDate, to: travelItemViewModel?.endDate)
        
//        travelItemViewModel?.createHistory(id: UUID(), isIncome: true, title: "수입", memo: nil, date: "2020-12-03".convertToDate(), image: Data(), amount: 5000, category: .income, isPrepare: false, isCard: false) { _ in
//            print("생성")
//        }
//        travelItemViewModel?.createHistory(id: UUID(), isIncome: false, title: "지출",memo: nil, date: "2020-12-03".convertToDate(), image: Data(), amount: 5000, category: .food, isPrepare: false, isCard: false) { _ in
//            print("생성")
//        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        moneySegmentedControl.selectedSegmentIndex = 0
        travelItemViewModel?.needFetchItems()
        travelItemViewModel?.didFetch = { [weak self] fetchedHistories in
            self?.historyListTableView.reloadData()
            self?.applySnapshot(with: fetchedHistories)
        }
    }
    
    @objc private func addHistory() {
        let addHistoryVC = AddHistoryViewController(nibName: AddHistoryViewController.identifier, bundle: nil)
        addHistoryVC.travelItemViewModel = self.travelItemViewModel
        self.present(addHistoryVC, animated: true) { [weak self] in
            self?.refresher.endRefreshing()
        }
    }
    
    private func configureSegmentedControl() {
        moneySegmentedControl.selectedSegmentTintColor = .clear
        moneySegmentedControl.backgroundColor = .none
        moneySegmentedControl.layer.backgroundColor = UIColor.clear.cgColor
        moneySegmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "AvenirNextCondensed-Medium", size: 12)!, NSAttributedString.Key.foregroundColor: UIColor.lightGray], for: .normal)
        moneySegmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "AvenirNextCondensed-Medium", size: 16)!, NSAttributedString.Key.foregroundColor: UIColor(named: "mainColor")], for: .selected)
    }
    
    private func configureTableView() {
        historyListTableView.refreshControl = refresher
        historyListTableView.delegate = self
        historyListTableView.register(HistoryCell.getNib(), forCellReuseIdentifier: HistoryCell.identifier)
        historyListTableView.register(HistoryHeaderCell.getNib(), forHeaderFooterViewReuseIdentifier: HistoryHeaderCell.identifier)
    }
    
    private func configureDatasource() -> DataSource {
        let datasource = DataSource(tableView: historyListTableView) { (tableview, indexPath, item) -> UITableViewCell? in
            guard let cell = tableview.dequeueReusableCell(withIdentifier: HistoryCell.identifier, for: indexPath) as? HistoryCell else { return UITableViewCell() }
            cell.configure(with: item)
            
            return cell
        }
        return datasource
    }
    
    private func applySnapshot(with histories: [HistoryItemViewModel]) {
        var snapshot = Snapshot()
        headers = setupSection(with: histories)
        snapshot.appendSections(headers)
        histories.forEach { history in
            if let section = headers.filter({ Calendar.current.isDate(history.date, inSameDayAs: $0.date) }).first {
                snapshot.appendItems([history], toSection: section)
            }
        }
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    private func setupSection(with histories: [HistoryItemViewModel]) -> [HistoryListSectionHeader] {
        guard let startDate = travelItemViewModel?.startDate else { return [] }
        var days = Set<HistoryListSectionHeader>()
        histories.forEach { history in
            let day = startDate.interval(ofComponent: .day, fromDate: history.date)
            let amount = history.amount
            let date = history.date
            if let day = days.filter({ Calendar.current.isDate(date, inSameDayAs: $0.date) }).first {
                day.amount += amount
            } else {
                days.insert(HistoryListSectionHeader(dayNumber: day + 1, date: date, amount: amount))
            }
        }
        var sections = [HistoryListSectionHeader](days)
        sections = sections.sorted(by: {$0.date < $1.date})
        return sections
    }
    
    private func setupDays(from startDate: Date?, to endDate: Date?) {
        guard let startDate = travelItemViewModel?.startDate,
              let endDate = travelItemViewModel?.endDate else { return }
        let days = startDate.getPeriodOfDates(with: endDate)
        days.forEach { day in
            setupDayCell(with: day)
        }
    }
    
    private func setupDayCell(with date: Date) {
        let view = DayCell(frame: CGRect(), date: date)
        view.delegate = self
        dayStackView.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 1/7).isActive = true
    }
    
    private func filterHistories(isPrepare: Bool?, date: Date?, isCard: Bool?) -> [HistoryItemViewModel] {
        var histories = travelItemViewModel?.histories ?? []
        if let card = isCard {
            histories = histories.filter { $0.isCard == card }
        }
        if let prepare = isPrepare, prepare {
            histories = histories.filter { $0.isPrepare == prepare }
        } else if let date = date {
            histories = histories.filter { Calendar.current.isDate(date, inSameDayAs: $0.date) }
        }
        return histories
    }
    
    @IBAction func moneySegmentedControlChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            isCard = nil
        case 1:
            isCard = false
        default:
            isCard = true
        }
        applySnapshot(with: filterHistories(isPrepare: isPrepareOnly, date: date, isCard: isCard))
    }
    
    @IBAction func allButtonTapped(_ sender: UIButton) {
        isPrepareOnly = false
        applySnapshot(with: filterHistories(isPrepare: isPrepareOnly, date: date, isCard: isCard))
    }
    
    @IBAction func prepareButtonTapped(_ sender: UIButton) {
        isPrepareOnly = true
        applySnapshot(with: filterHistories(isPrepare: isPrepareOnly, date: date, isCard: isCard))
    }
    
}

extension HistoryListViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        guard let selectedHistoryViewModel = dataSource.itemIdentifier(for: indexPath) else { return }
        if let historyDetailVC = self.storyboard?.instantiateViewController(identifier: "HistoryDetailViewController") as? HistoryDetailViewController {
            self.present(historyDetailVC, animated: true, completion: nil)
            historyDetailVC.initDetailView(history: selectedHistoryViewModel)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return view.bounds.height * 0.1
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: HistoryHeaderCell.identifier) as? HistoryHeaderCell,
              // TODO: - 더 효율적으로 빈 headers 처리하는 방법 고민하기
              !headers.isEmpty
        else { return nil }
        headerView.configure(with: headers[section].dayNumber, date: headers[section].date, amount: headers[section].amount)
        return headerView
    }
}

extension HistoryListViewController: DayButtonDelegate {
    func dayButtonTapped(_ sender: UIButton) {
        let subviews = dayStackView.subviews
        for index in 0..<subviews.count {
            if let _ = subviews[index].subviews.filter({ $0 == sender }).first as? UIButton {
                guard let startDate = travelItemViewModel?.startDate,
                      let tappedDate = Calendar.current.date(byAdding: .day, value: index, to: startDate) else { return }
                date = tappedDate
                isPrepareOnly = nil
                break
            }
        }
        applySnapshot(with: filterHistories(isPrepare: isPrepareOnly, date: self.date, isCard: isCard))
    }
    
}
