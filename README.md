[![Build status](https://badge.buildkite.com/aeca41d936ba150f724a0c53831466d1d0377ac34a286b2ee9.svg)](https://buildkite.com/blindingskies/money-fx?branch=development)
[![codecov.io](https://codecov.io/github/danthorpe/FX/coverage.svg?branch=master)](https://codecov.io/github/danthorpe/FX?branch=development)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/MoneyFX.svg)](https://img.shields.io/cocoapods/v/MoneyFX.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Platform](https://img.shields.io/cocoapods/p/MoneyFX.svg?style=flat)](http://cocoadocs.org/docsets/MoneyFX)

# FX

FX is a Swift framework for iOS, watchOS, tvOS and OS X. It provides support for Foreign Currency Exchange to the [Money](https://github.com/danthorpe/Money) framework.

## Foreign Currency Exchange (FX)
To represent a foreign exchange transaction, i.e. converting `USD` to `EUR`, use a FX service provider. There is built in support for [Yahoo](https://finance.yahoo.com/currency-converter/#from=USD;to=EUR;amt=1) and [OpenExchangeRates.org](https://openexchangerates.org) services. But it’s possible for consumers to create their own too.

The following code snippet represents a currency exchange using Yahoo’s currency converter.

```swift
Yahoo<USD,EUR>.quote(100) { result in
    if let tx = result.value {
        print("Exchanged \(tx.base) into \(tx.counter) with a rate of \(tx.rate) and \(tx.commission) commission.")
    }
}
```

> Exchanged US$ 100.00 into € 93.09 with a rate of 0.93089 and US$ 0.00 commission.

The result, delivered asynchronously, uses [`Result`](http://github.com/antitypical/Result) to encapsulate either a `FXTransaction` or an `FXError` value. Obviously, in real code - you’d need to check for errors ;)

`FXTransaction` is a generic type which composes the base and counter monies, the rate of the exchange, and any commission the FX service provider charged in the base currency. Currently `FXQuote` only supports percentage based commission.

There is a neat convenience function which just returns the `CounterMoney` as its `Result` value type.

```swift
Yahoo<USD,EUR>.fx(100) { euros in
    print("You got \(euros)")
}
```

> You got .Success(€ 93.09)

### Creating custom FX service providers

Creating a custom FX service provider is straightforward. The protocols `FXLocalProviderType` and `FXRemoteProviderType` define the minimum requirements. The `quote` and `fx` methods are provided via extensions on the protocols.

For a remote FX service provider, i.e. one which will make a network request to get a rate, we can look at the `Yahoo` provider to see how it works.

Firstly, we subclass the generic class `FXRemoteProvider`. The generic types are both constrained to `MoneyType`. The naming conventions follow those of a [currency pair](https://en.wikipedia.org/wiki/Currency_pair).

```swift
public class Yahoo<B: MoneyType, C: MoneyType>: FXRemoteProvider<B, C>, FXRemoteProviderType {
    // etc
}
```

`FXRemoteProvider` provides the typealiases for `BaseMoney` and `CounterMoney` which will be needed to introspect the currency codes.

The protocol requires that we can construct a `NSURLRequest`.

```swift
public static func request() -> NSURLRequest {
  return NSURLRequest(URL: NSURL(string: "https://download.finance.yahoo.com/d/quotes.csv?s=\(BaseMoney.Currency.code)\(CounterMoney.Currency.code)=X&f=nl1")!)
}
```

The last requirement, is that the network result can be mapped into a `Result<FXQuote,FXError>`.

`FXQuote` is a struct, which composes the exchange rate and percentage commission to be used. Both properties are `BankersDecimal` values (see below on the decimal implementation details).

```swift
public static func quoteFromNetworkResult(result: Result<(NSData?, NSURLResponse?), NSError>) -> Result<FXQuote, FXError> {
  return result.analysis(
    ifSuccess: { data, response in
      let rate: BankersDecimal = 1.5 // or whatever	 
      return Result(value: FXQuote(rate: rate))
    },
    ifFailure: { error in
      return Result(error: .NetworkError(error))
    }
  )
}
```

Note that the provider doesn’t need to perform any networking itself. It is all done by the framework. This is a deliberate architectural design as it makes it much easier to unit test the adaptor code.

## Bitcoin

FX has support for using [CEX.IO](https://cex.io)’s [trade api](https://cex.io/api) to support quotes of Bitcoin currency exchanges. CEX only supports `USD`, `EUR,` and `RUB` [fiat currencies](https://en.wikipedia.org/wiki/Fiat_money). 

It’s usage is a little bit different for a regular FX. To represent the purchase of Bitcoins use `CEXBuy` like this:

```swift
CEXBuy<USD>.quote(100) { result in
    if let tx = result.value {
        print("\(tx.base) will buy \(tx.counter) at a rate of \(tx.rate) with \(tx.commission)")
    }
}
```
> US$ 100.00 will buy Ƀ0.26219275 at a rate of 0.0026272 with US$ 0.20 commission.

To represent the sale of Bitcoins use `CEXSell` like this:

```swift
CEXSell<EUR>.quote(50) { result in
    if let tx = result.value {
        print("\(tx.base) will sell for \(tx.counter) at a rate of \(tx.rate) with \(tx.commission) commission.")
    }
}
```
> Ƀ50.00 will sell for € 17,541.87 at a rate of 351.5405 with Ƀ0.10 commission.

If trying to buy or sell using a currency not supported by CEX the compiler will prevent your code from compiling.

```swift
CEXSell<GBP>.quote(50) { result in
    // etc
}
```
> Type 'Currency.GBP' does not conform to protocol 'CEXSupportedFiatCurrencyType'
