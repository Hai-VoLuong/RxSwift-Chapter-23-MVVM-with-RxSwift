//
//  ListTimelineViewModel.swift
//  Tweetie
//
//  Created by Marin Todorov on 12/5/16.
//  Copyright © 2016 Underplot ltd. All rights reserved.
//

import XCTest
import Accounts
import RxSwift
import RxCocoa
import RxTest
import Unbox
import RealmSwift

@testable import Tweetie

class ListTimelineViewModelTests: XCTestCase {

  private func createViewModel(_ account: Driver<TwitterAccount.AccountStatus>) -> ListTimelineViewModel {
    return ListTimelineViewModel(
      account: account,
      list: TestData.listId,
      apiType: TwitterTestAPI.self)
  }

  func test_whenInitialized_storesInitParams() {
    let accountSubject = PublishSubject<TwitterAccount.AccountStatus>()
    let viewModel = createViewModel(accountSubject.asDriver(onErrorJustReturn: .unavailable))

    XCTAssertNotNil(viewModel.account)
    XCTAssertEqual(viewModel.list.username+viewModel.list.slug, TestData.listId.username+TestData.listId.slug)
    XCTAssertFalse(viewModel.paused)
  }

    func test_whenAccountAvailable_updatesAccountStatus() {
        let asyncExpect = expectation(description: "fullfill test")
        let scheduler = TestScheduler(initialClock: 0)
        let observer = scheduler.createObserver(Bool.self)

        let accountSubject = PublishSubject<TwitterAccount.AccountStatus>()
        let viewModel = createViewModel(accountSubject.asDriver(onErrorJustReturn: .unavailable))

        let bag = DisposeBag()
        let loggedIn = viewModel.loggedIn.asObservable().share()

        loggedIn
        .subscribe(observer)
        .addDisposableTo(bag)

        loggedIn
        .subscribe(onCompleted: asyncExpect.fulfill)
        .addDisposableTo(bag)

        accountSubject.onNext(.authorized(TestData.account))
        accountSubject.onNext(.unavailable)
        accountSubject.onCompleted()

        waitForExpectations(timeout: 1.0, handler: { error in
            XCTAssert((error != nil), error!.localizedDescription)
            let expectedEvents = [next(0, true), next(0, false), completed(0)]
            XCTAssertEqual(observer.events, expectedEvents)
        })

    }

  func test_whenInitialized_bindsTweets() {
    let asyncExpect = expectation(description: "fullfill test")

    Realm.useCleanMemoryRealmByDefault(identifier: #function)

    let realm = try! Realm()
    try! realm.write {
      realm.add(TestData.tweets)
    }

    let accountSubject = PublishSubject<TwitterAccount.AccountStatus>()
    let viewModel = createViewModel(accountSubject.asDriver(onErrorJustReturn: .unavailable))

    var emitted = [(AnyRealmCollection<Tweet>, RealmChangeset?)]()
    _ = viewModel.tweets
      .subscribe(onNext: { value in
        emitted.append(value)
        asyncExpect.fulfill()
      })

    waitForExpectations(timeout: 1.0, handler: { error in
      XCTAssertNil(error, "error: \(error!.localizedDescription)")
      XCTAssertTrue(emitted.count > 0)
      XCTAssertTrue(emitted[0].0.count == 3)
      XCTAssertEqual(TwitterTestAPI.lastMethodCall, "timeline(of:)")
    })
  }

}
