//
//  Date+FirebaseTimestamp.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 12/11/25.
//

import Foundation

extension Date {
    // Pure helpers – keep them nonisolated
    nonisolated static func fromFirebaseTimestamp(_ timestamp: Int64) -> Date {
        Date(timeIntervalSince1970: Double(timestamp))
    }
    
    nonisolated func toFirebaseTimestamp() -> Int64 {
        Int64(timeIntervalSince1970.rounded())
    }
}
