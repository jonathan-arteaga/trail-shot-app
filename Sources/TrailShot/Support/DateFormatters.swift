import Foundation

extension Date {
    var trailShotTimestamp: String {
        formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
