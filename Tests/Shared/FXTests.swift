//
//  FXTests.swift
//  Money
//
//  Created by Daniel Thorpe on 02/11/2015.
//
//

import XCTest
import Result
import SwiftyJSON
import DVR
import Money
@testable import MoneyFX

class Sessions {

    static func sessionWithCassetteName(name: String) -> Session {
		return sharedInstance.sessionWithCassetteName(name: name)
    }

    static let sharedInstance = Sessions()

    var sessions = Dictionary<String, Session>()

    func sessionWithCassetteName(name: String) -> Session {
        guard let session = sessions[name] else {
            let _session = Session(cassetteName: name)
            sessions.updateValue(_session, forKey: name)
            return _session
        }
        return session
    }
}

func createGarbageData() -> Data {
    return MoneyTestHelper.createGarbageData()
}

class MoneyTestHelper {
    static func createGarbageData() -> Data {
        let url = Bundle(for: MoneyTestHelper.self).url(forResource: "Troll", withExtension: "png")
        let data = try! Data(contentsOf: url!)
        return data
    }
}

class TestableFXRemoteProvider<Provider: FXRemoteProviderType>: FXRemoteProviderType {

    typealias CounterMoney = Provider.CounterMoney
    typealias BaseMoney = Provider.BaseMoney

    static func name() -> String {
        return Provider.name()
    }

    static func session() -> URLSession {
		return Sessions.sessionWithCassetteName(name: name())
    }

    static func request() -> URLRequest {
        return Provider.request()
    }

    static func quoteFromNetworkResult(result: Result<(Data?, URLResponse?), NSError>) -> Result<FXQuote, FXError> {
		return Provider.quoteFromNetworkResult(result: result)
    }
}

class FaultyFXRemoteProvider<Provider: FXRemoteProviderType>: FXRemoteProviderType {

    typealias CounterMoney = Provider.CounterMoney
    typealias BaseMoney = Provider.BaseMoney

    static func name() -> String {
        return Provider.name()
    }

    static func session() -> URLSession {
        return Provider.session()
    }

    static func request() -> URLRequest {
        let request = Provider.request()
        if let url = request.url,
			let host = url.host,
			let modified = URL(string: url.absoluteString.replacingOccurrences(of: host, with: "broken-host.xyz")) {
                return URLRequest(url: modified)
        }
        return request
    }

    static func quoteFromNetworkResult(result: Result<(Data?, URLResponse?), NSError>) -> Result<FXQuote, FXError> {
		return Provider.quoteFromNetworkResult(result: result)
    }
}

class FakeLocalFX<B: ISOMoneyProtocol, C: ISOMoneyProtocol>: FXLocalProviderType {
	
	typealias BaseMoney = B
    typealias CounterMoney = C

    static func name() -> String {
        return "LocalFX"
    }

    static func quote() -> FXQuote {
        return FXQuote(rate: 1.1)
    }
}


class FXErrorTests: XCTestCase {

    func test__fx_error__equality() {
        XCTAssertNotEqual(FXError.noData, FXError.rateNotFound("whatever"))
    }
}

class FXProviderTests: XCTestCase {

    func dvrJSONFromCassette(name: String) -> JSON? {
		do {
			guard let url = Bundle(for: FXProviderTests.self).url(forResource: name, withExtension: "json") else {
				return nil
			}
			let json = try JSON(data: Data(contentsOf: url))
			let body = json[["interactions",0,"response","body"]]
			
			return body
			
		} catch {
			return nil
		}
    }
}

class FXLocalProviderTests: XCTestCase {

    func test_fx() {
        XCTAssertEqual(FakeLocalFX<GBP, USD>.fx(100).counter, 110)
    }
}
