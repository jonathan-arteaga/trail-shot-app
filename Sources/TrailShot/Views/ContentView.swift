import SwiftUI

@MainActor
struct ContentView: View {
    @Bindable var store: CaptureStore

    var body: some View {
        NavigationSplitView {
            CaptureSidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                HeaderView(store: store)
                Divider()
                CaptureDetailView(store: store)
            }
        }
        .sheet(isPresented: $store.isShowingWindowPicker) {
            WindowPickerView(store: store)
        }
    }
}
