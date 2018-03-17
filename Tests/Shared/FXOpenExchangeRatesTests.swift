//
//  FXOpenExchangeRatesTests.swift
//  Money
//
//  Created by Daniel Thorpe on 04/11/2015.
//
//

import XCTest
import Result
import DVR
import SwiftyJSON
import Money
@testable import MoneyFX

struct MyOpenExchangeRatesAppID: OpenExchangeRatesAppID {
    static let app_id = "this_is_not_the_app_id_youre_looking_for"
}

class OpenExchangeRates<Base: ISOMoneyProtocol, Counter: ISOMoneyProtocol>: _OpenExchangeRates<Base, Counter, MyOpenExchangeRatesAppID> { }

class FreeOpenExchangeRates<Counter: ISOMoneyProtocol>: _ForeverFreeOpenExchangeRates<Counter, MyOpenExchangeRatesAppID> { }

class FXPaidOpenExchangeRatesTests: FXProviderTests {
    typealias Provider = OpenExchangeRates<GBP,JPY>

    func test__name() {
        XCTAssertEqual(Provider.name(), "OpenExchangeRates.org GBPJPY")
    }

    func test__base_currency() {
		XCTAssertEqual(Provider.BaseMoney.ISOCurrency.shared.code, GBP.ISOCurrency.shared.code)
    }

    func test__request__url_does_contain_base() {
        guard let url = Provider.request().url else {
            XCTFail("Request did not return a URL")
            return
        }

        XCTAssertTrue(url.absoluteString.contains("&base=GBP"))
    }
}

class FXFreeOpenExchangeRatesTests: FXProviderTests {

    typealias Provider = FreeOpenExchangeRates<EUR>
    typealias TestableProvider = TestableFXRemoteProvider<Provider>
    typealias FaultyProvider = FaultyFXRemoteProvider<Provider>

    func test__name() {
        XCTAssertEqual(Provider.name(), "OpenExchangeRates.org USDEUR")
    }

    func test__session() {
        XCTAssertEqual(Provider.session(), URLSession.shared)
    }

    func test__base_currency() {
		XCTAssertEqual(Provider.BaseMoney.ISOCurrency.shared.code, USD.ISOCurrency.shared.code)
    }

    func test__request__url_does_not_contain_base() {
        guard let url = Provider.request().url else {
            XCTFail("Request did not return a URL")
            return
        }

        XCTAssertFalse(url.absoluteString.contains("&base="))
    }

    func test__quote_adaptor__with_network_error() {
        let error = NSError(domain: SwiftyJSONError.errorDomain, code: URLError.badServerResponse.rawValue, userInfo: nil)
        let network: Result<(Data?, URLResponse?), NSError> = Result(error: error)
		let quote = Provider.quoteFromNetworkResult(result: network) 
        XCTAssertEqual(quote.error!, FXError.networkError(error))
    }

    func test__quote_adaptor__with_no_data() {
        let network: Result<(Data?, URLResponse?), NSError> = Result(value: (.none, .none))
		let quote = Provider.quoteFromNetworkResult(result: network)
        XCTAssertEqual(quote.error!, FXError.noData)
    }

    func test__quote_adaptor__with_garbage_data() {
        let data = createGarbageData()
        let network: Result<(Data?, URLResponse?), NSError> = Result(value: (data, .none))
		let quote = Provider.quoteFromNetworkResult(result: network)
		print(quote.error)
        XCTAssertEqual(quote.error!, FXError.invalidData(data))
    }

    func test__quote_adaptor__with_missing_rate() {
		var json = dvrJSONFromCassette(name: Provider.name())!
        var rates: Dictionary<String, JSON> = json["rates"].dictionary!
		rates.removeValue(forKey: "EUR")
        json["rates"] = JSON(rates)
        let data = try! json.rawData()
        let network: Result<(Data?, URLResponse?), NSError> = Result(value: (data, .none))
		let quote = Provider.quoteFromNetworkResult(result: network)
        XCTAssertEqual(quote.error!, FXError.rateNotFound(Provider.name()))
    }

    func test__faulty_provider() {
		let expect = expectation(description: "Test: \(#function)")

        FaultyProvider.fx(100) { result in
            guard let error = result.error else {
                XCTFail("Should have received a network error.")
                return
            }
            switch error {
            case .networkError(_):
                break // This is the success path.
            default:
                XCTFail("Returned \(error), should be a .NetworkError")
            }
            expect.fulfill()
        }
		
		waitForExpectations(timeout: 1, handler: nil)
    }

    func test__fx() {
		let expect = expectation(description: "Test: \(#function)")
		
        TestableProvider.fx(100) { result in
            if let eur = result.value {
				XCTAssertEqualWithAccuracy((eur.decimal as NSDecimalNumber).doubleValue, 92.09, accuracy: 0.01)
            }
            else {
                XCTFail("Received error: \(result.error!).")
            }
            expect.fulfill()
        }

        waitForExpectations(timeout: 1, handler: nil)
    }
}
