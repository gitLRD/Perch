import Foundation
@testable import PerchCore

func updaterTests() {
    T.run("semver comparison") {
        T.check(Updater.isNewer("0.2.0", than: "0.1.0"), "0.2.0 > 0.1.0")
        T.check(Updater.isNewer("0.10.0", than: "0.9.0"), "0.10.0 > 0.9.0 (numeric, not lexical)")
        T.check(Updater.isNewer("1.0.0", than: "0.9.9"), "1.0.0 > 0.9.9")
        T.check(!Updater.isNewer("0.1.0", than: "0.1.0"), "equal is not newer")
        T.check(!Updater.isNewer("0.1.0", than: "0.2.0"), "older is not newer")
        T.check(Updater.isNewer("0.2.1", than: "0.2.0"), "0.2.1 > 0.2.0")
    }
}
