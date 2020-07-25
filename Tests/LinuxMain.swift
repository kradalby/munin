import XCTest

import MuninKitTests
import MuninTests

var tests = [XCTestCaseEntry]()
tests += MuninKitTests.__allTests()
tests += MuninTests.__allTests()

XCTMain(tests)
