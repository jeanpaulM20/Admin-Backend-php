import SwiftUI

/// Die fünf Bereiche der App. Einstellungen sind bewusst kein Tab, sondern
/// sitzen hinter dem Avatar oben rechts — iOS bricht ab dem sechsten Tab in
/// einen „More"-Tab um und zerstört damit die wertbasierte Navigation.
enum AppSection: String, CaseIterable, Identifiable {
    case home, clients, trainings, calendar, chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:      return "Übersicht"
        case .clients:   return "Kunden"
        case .trainings: return "Trainings"
        case .calendar:  return "Kalender"
        case .chat:      return "Nachrichten"
        }
    }

    var icon: String {
        switch self {
        case .home:      return "square.grid.2x2"
        case .clients:   return "person.2"
        case .trainings: return "figure.strengthtraining.traditional"
        case .calendar:  return "calendar"
        case .chat:      return "bubble.left.and.bubble.right"
        }
    }

    @ViewBuilder var root: some View {
        switch self {
        case .home:      HomeView()
        case .clients:   ClientsListView()
        case .trainings: TrainingsView()
        case .calendar:  CalendarView()
        case .chat:      ChatView()
        }
    }
}

#if DEBUG
/// Startargument `-section <id>` wählt den Bereich beim Start. Nur für das
/// automatisierte Prüfen der Ansichten; in Release-Builds nicht vorhanden.
private var launchSection: AppSection {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-section"),
          index + 1 < arguments.count,
          let section = AppSection(rawValue: arguments[index + 1]) else { return .home }
    return section
}
#else
private var launchSection: AppSection { .home }
#endif

/// Auf dem iPhone Tabs, auf dem iPad eine Seitenleiste mit Detailbereich.
/// Ein Codestand, zwei Erscheinungsbilder — die Screens selbst wissen nichts
/// davon.
struct MainView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var store: TrainerStore
    @EnvironmentObject private var chat: ChatStore
    @EnvironmentObject private var calendarStore: CalendarStore

    var body: some View {
        Group {
            if sizeClass == .regular {
                SidebarLayout()
            } else {
                TabLayout()
            }
        }
        .task(id: auth.trainer?.id) {
            guard let trainer = auth.trainer else { return }
            #if DEBUG
            if auth.isPreview {
                store.loadPreviewData()
                chat.loadPreviewData()
                calendarStore.loadPreviewData()
                return
            }
            #endif
            await store.load(trainerId: trainer.id)
            async let conversations: Void = chat.load(trainerId: trainer.id)
            async let availability: Void = calendarStore.load(trainerId: trainer.id)
            _ = await (conversations, availability)
        }
    }
}

/// iPhone: ein NavigationStack PRO Tab (nie einer um die TabView).
private struct TabLayout: View {
    @State private var selection: AppSection = launchSection

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                NavigationStack {
                    section.root
                }
                .tabItem {
                    Label(section.title, systemImage: section.icon)
                }
                .tag(section)
            }
        }
    }
}

/// iPad: Seitenleiste links, Inhalt rechts. Der Detailbereich bekommt seinen
/// eigenen NavigationStack, damit Push-Navigation innerhalb eines Bereichs
/// funktioniert.
private struct SidebarLayout: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var selection: AppSection? = launchSection
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .font(.app(15))
                    .tag(section)
            }
            .navigationTitle(auth.trainer?.name ?? "SIHL Trainer")
            .scrollContentBackground(.hidden)
            .background(AppColor.surface)
        } detail: {
            NavigationStack {
                (selection ?? .home).root
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
