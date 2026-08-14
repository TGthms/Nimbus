import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsPresented = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(model: model)
            mainStage
            if model.inspectorVisible {
                InspectorView(model: model)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .environment(\.layoutDirection, model.language.isRTL ? .rightToLeft : .leftToRight)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring, value: model.inspectorVisible)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.heroSpring, value: model.selectedPlaceID)
        .background(Color.black.opacity(0.2))
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task { await model.refreshSelected(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(model.t("refresh"))
                .keyboardShortcut("r", modifiers: [.command])

                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring) {
                        model.inspectorVisible.toggle()
                    }
                    Task { await model.persist(); await model.loadInspectorIfNeeded() }
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .help(model.t("inspector"))
                .keyboardShortcut("i", modifiers: [.command])

                Button {
                    settingsPresented = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(model.t("settings"))
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
        .sheet(isPresented: $settingsPresented) {
            SettingsView(model: model, showsDone: true)
        }
        .onAppear {
            Task { await model.bootstrap() }
        }
        .onChange(of: model.location.coordinate?.latitude) { _, _ in
            Task { await model.refreshSelected(force: true) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refreshSelected(force: false) }
            }
        }
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .up, .left: model.previousPlace()
            case .down, .right: model.nextPlace()
            default: break
            }
        }
    }

    private var mainStage: some View {
        ZStack {
            scene
            if let snapshot = model.selectedSnapshot {
                forecastStack(snapshot)
                    .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 10)))
            } else {
                emptyState
            }
            if let banner = model.banner {
                VStack {
                    Text(banner)
                        .font(.callout)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .nimbusGlass(.regularMaterial, radius: 12)
                        .padding(.top, 12)
                    Spacer()
                }
            }
            if let module = model.expandedModule, let snapshot = model.selectedSnapshot {
                ModuleDetailOverlay(
                    module: module,
                    snapshot: snapshot,
                    units: model.units,
                    language: model.language,
                    recipe: snapshot.sceneRecipe
                ) {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring) {
                        model.expandedModule = nil
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring, value: model.expandedModule)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring, value: model.inspectorVisible)
    }

    @ViewBuilder
    private var scene: some View {
        if let snapshot = model.selectedSnapshot {
            WeatherSceneView(
                recipe: snapshot.sceneRecipe,
                isActive: scenePhase == .active,
                motionPreference: model.settings.motion
            )
        } else {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.32, blue: 0.58), Color(red: 0.45, green: 0.62, blue: 0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func forecastStack(_ snapshot: WeatherSnapshot) -> some View {
        let recipe = snapshot.sceneRecipe
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeroView(snapshot: snapshot, units: model.units, recipe: recipe, language: model.language)
                HourlyStripView(
                    snapshot: snapshot,
                    units: model.units,
                    focusedDay: model.focusedDay,
                    recipe: recipe,
                    language: model.language
                )
                DailyForecastView(
                    snapshot: snapshot,
                    units: model.units,
                    focusedDay: model.focusedDay,
                    recipe: recipe,
                    language: model.language
                ) { day in
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring) {
                        if let focused = model.focusedDay, Calendar.current.isDate(focused, inSameDayAs: day) {
                            model.focusedDay = nil
                        } else {
                            model.focusedDay = day
                        }
                    }
                }
                ModuleGridView(
                    snapshot: snapshot,
                    units: model.units,
                    language: model.language,
                    recipe: recipe
                ) { module in
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : NimbusTheme.panelSpring) {
                        model.expandedModule = module
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            if model.selectedPlace.isCurrentLocation && !model.location.isAuthorized {
                Image(systemName: "location.slash")
                    .font(.largeTitle)
                Text(model.t("location_needed"))
                    .font(.title2.weight(.semibold))
                Button(model.t("enable_location")) { model.location.request() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
            } else if model.isRefreshing {
                ProgressView()
            }
        }
        .foregroundStyle(.white)
        .shadow(radius: 8)
        .frame(maxWidth: 360)
        .multilineTextAlignment(.center)
    }
}
