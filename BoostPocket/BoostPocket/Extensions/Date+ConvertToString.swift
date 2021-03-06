//
//  Date+ConvertToString.swift
//  BoostPocket
//
//  Created by 이승진 on 2020/11/26.
//  Copyright © 2020 BoostPocket. All rights reserved.
//

import Foundation

enum DateFormats: String {
    case dotted = "yyyy. MM. dd."
    case dashed = "yyyy-MM-dd."
    case korean = "yyyy년 MM월 dd일"
}

extension Date {
    func convertToString(format: DateFormats) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = format.rawValue
        return formatter.string(from: self)
    }
}
