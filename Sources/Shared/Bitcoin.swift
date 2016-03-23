//
//  Bitcoin.swift
//  Money
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Daniel Thorpe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Result
import SwiftyJSON
import Money

// MARK - cex.io FX

/**
 CEX.io Supported fiat currencies

 CEX only supports USD, EUR and RUB.

 - see: https://cex.io
*/
public protocol CEXSupportedFiatCurrencyType: ISOCurrencyType {

    /**
     CEX.io charge a percentage based commission with FX transactions.
     - returns: a BankersDecimal representing the % commission.
    */
    static var cex_commissionPercentage: BankersDecimal { get }
}

extension Currency.USD: CEXSupportedFiatCurrencyType {

    /// - returns: the commission charged for USD transactions, a BankersDecimal
    public static let cex_commissionPercentage: BankersDecimal = 0.2
}

extension Currency.EUR: CEXSupportedFiatCurrencyType {

    /// - returns: the commission charged for EUR transactions, a BankersDecimal
    public static let cex_commissionPercentage: BankersDecimal = 0.2
}

extension Currency.RUB: CEXSupportedFiatCurrencyType {

    /// - returns: the commission charged for RUB transactions, a BankersDecimal
    public static let cex_commissionPercentage: BankersDecimal = 0
}

struct _CEXBuy<Base: MoneyType where Base.Currency: CEXSupportedFiatCurrencyType>: CryptoCurrencyMarketTransactionType {
    typealias BaseMoney = Base
    typealias CounterMoney = BTC
    typealias FiatCurrency = Base.Currency
    static var transactionKind: CurrencyMarketTransactionKind { return .Buy }
}

struct _CEXSell<Counter: MoneyType where Counter.Currency: CEXSupportedFiatCurrencyType>: CryptoCurrencyMarketTransactionType {
    typealias BaseMoney = BTC
    typealias CounterMoney = Counter
    typealias FiatCurrency = Counter.Currency
    static var transactionKind: CurrencyMarketTransactionKind { return .Sell }
}

class _CEX<T: CryptoCurrencyMarketTransactionType where T.FiatCurrency: CEXSupportedFiatCurrencyType>: FXRemoteProvider<T.BaseMoney, T.CounterMoney>, FXRemoteProviderType {

    static func name() -> String {
        return "CEX.IO \(BaseMoney.Currency.code)\(CounterMoney.Currency.code)"
    }

    static func request() -> NSURLRequest {
        let url = NSURL(string: "https://cex.io/api/convert/\(BTC.Currency.code)/\(T.FiatCurrency.code)")
        let request = NSMutableURLRequest(URL: url!)
        request.HTTPMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let data = try JSON(["amnt": Double(1.0)]).rawData()
            request.HTTPBody = data
        } catch {
            print("Caught error: \(error) accessing JSON data for `amnt`.")
        }
        return request
    }

    static func quoteFromNetworkResult(result: Result<(NSData?, NSURLResponse?), NSError>) -> Result<FXQuote, FXError> {
        return result.analysis(

            ifSuccess: { data, response in

                guard let data = data else {
                    return Result(error: .NoData)
                }

                let json = JSON(data: data)

                if json.isEmpty {
                    return Result(error: .InvalidData(data))
                }

                guard let rateLiteral = json["amnt"].double else {
                    return Result(error: .RateNotFound(name()))
                }

                let rate: BankersDecimal

                switch T.transactionKind {
                case .Buy:
                    rate = BankersDecimal(floatLiteral: rateLiteral).reciprocal
                case .Sell:
                    rate = BankersDecimal(floatLiteral: rateLiteral)
                }

                return Result(value: FXQuote(rate: rate, percentage: T.FiatCurrency.cex_commissionPercentage))
            },

            ifFailure: { error in
                return Result(error: .NetworkError(error))
            })
    }
}

/**
  Represents the purchase of bitcoin using CEX.io.

  Usage is entirely type based - there is nothing to initialize. It is
  generic over USD, EUR or RUB, no other currency types. For example.

  ```swift
  CEXBuy<USD>.quote(1_000) { transaction in
    // etc.
  }
  ```

  The above sample represents buying US$1,000 worth of BTC using CEX.io.
*/
public final class CEXBuy<Base: MoneyType where Base.Currency: CEXSupportedFiatCurrencyType>: _CEX<_CEXBuy<Base>> { }

 /**
  Represents the sale of bitcoin using CEX.io.

  Usage is entirely type based - there is nothing to initialize. It is
  generic over USD, EUR or RUB, no other currency types. For example.

  ```swift
  CEXBuy<EUR>.quote(10) { transaction in
  // etc.
  }
  ```

  The above sample represents selling 10 bitcoins for euros using CEX.io.
  */
public final class CEXSell<Counter: MoneyType where Counter.Currency: CEXSupportedFiatCurrencyType>: _CEX<_CEXSell<Counter>> { }
