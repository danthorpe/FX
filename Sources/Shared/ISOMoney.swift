//
//  ISOMoney.swift
//  FX-iOS
//
//  Created by Marco Betschart on 17.03.18.
//

import Foundation
import Money

public protocol ISOMoneyProtocol {
	associatedtype ISOCurrency: ISOCurrencyProtocol
	var decimal: Decimal { get }

	init(decimal: Decimal)
}

extension ISOMoney: ISOMoneyProtocol {
	public typealias ISOCurrency = C
}
