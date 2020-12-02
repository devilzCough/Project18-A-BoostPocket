//
//  HistoryCell.swift
//  BoostPocket
//
//  Created by 송주 on 2020/12/02.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import UIKit

class HistoryCell: UITableViewCell {
    
    static let identifier = "HistoryCell"

    @IBOutlet weak var categoryImageView: UIImageView!
    @IBOutlet weak var costLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configure(with history: DummyHistory) {
        categoryImageView.image = UIImage(named: history.category.name)
        costLabel.text = "\(history.amount)"
        titleLabel.text = history.title
        dateLabel.text = history.date.convertToString(format: .dotted)
    }
    
    static func getNib() -> UINib {
        return UINib(nibName: HistoryCell.identifier, bundle: nil)
    }
}
