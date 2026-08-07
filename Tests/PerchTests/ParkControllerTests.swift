import Foundation
@testable import PerchCore

func parkControllerTests() {
    T.run("starts un-parked") {
        let p = ParkController()
        T.check(!p.isParked, "fresh controller is not parked")
        T.check(!p.shouldFlyHome(now: 1000), "un-parked never flies home")
    }

    T.run("didDrag arms parking for 15s") {
        var p = ParkController()
        p.didDrag(now: 100)
        T.check(p.isParked, "parked after drag")
        T.check(!p.shouldFlyHome(now: 114), "not home 1s before deadline")
        T.check(p.shouldFlyHome(now: 115), "home at deadline")
        T.check(p.shouldFlyHome(now: 200), "home after deadline")
    }

    T.run("a later drag pushes the deadline out") {
        var p = ParkController()
        p.didDrag(now: 100)
        p.didDrag(now: 110)          // re-arm
        T.check(!p.shouldFlyHome(now: 115), "old deadline no longer applies")
        T.check(p.shouldFlyHome(now: 125), "new deadline 110+15 applies")
    }

    T.run("reset clears parking") {
        var p = ParkController()
        p.didDrag(now: 100)
        p.reset()
        T.check(!p.isParked, "reset un-parks")
        T.check(!p.shouldFlyHome(now: 200), "reset stops fly-home")
    }

    T.run("parkDuration is 15") {
        T.equal(ParkController.parkDuration, 15, "duration constant")
    }
}
