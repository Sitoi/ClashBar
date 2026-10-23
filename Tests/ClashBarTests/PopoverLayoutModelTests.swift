import XCTest
@testable import ClashBar

final class PopoverLayoutModelTests: XCTestCase {
    @MainActor
    func testResizeClampsToControlsAndScreenAndResumesAutomaticHeight() {
        let layout = PopoverLayoutModel(maxPanelHeight: 800, preferredPanelHeight: 600)
        layout.resizePanelHeight(to: 100, minimum: 360)
        XCTAssertEqual(layout.resolvedPanelHeight, 360)
        layout.resizePanelHeight(to: 1200, minimum: 360)
        XCTAssertEqual(layout.resolvedPanelHeight, 800)
        layout.updateMaximumPanelHeight(500)
        XCTAssertEqual(layout.resolvedPanelHeight, 500)
        layout.resumeAutomaticHeight()
        layout.requestPanelHeight(320)
        XCTAssertNil(layout.userPanelHeight)
        XCTAssertEqual(layout.resolvedPanelHeight, 320)
    }

    @MainActor
    func testSmallScreenWinsOverMinimumAndInvalidDragIsIgnored() {
        let layout = PopoverLayoutModel(maxPanelHeight: 240)
        layout.resizePanelHeight(to: 400, minimum: 360)
        XCTAssertEqual(layout.resolvedPanelHeight, 240)
        layout.resizePanelHeight(to: .nan, minimum: 360)
        XCTAssertEqual(layout.resolvedPanelHeight, 240)
        XCTAssertEqual(layout.userPanelHeight, 240)
    }
}
