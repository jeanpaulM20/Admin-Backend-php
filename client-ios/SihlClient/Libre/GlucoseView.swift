import SwiftUI

/// FreeStyle Libre CGM-Daten-Screen — Pendant zu Flutter `glucose_screen.dart`.
struct GlucoseView: View {
    @Environment(LibreViewModel.self) private var vm

    var body: some View {
        if !vm.isLoggedIn {
            LibreLoginView()
        } else {
            glucoseContent
        }
    }

    private var glucoseContent: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: []) {
                        if let error = vm.error {
                            ErrorBanner(message: error)
                        }
                        if let latest = vm.latestReading {
                            CurrentValueCard(reading: latest)
                        }
                        if let lastSync = vm.lastSync {
                            SyncInfo(lastSync: lastSync, fromCache: vm.fromCache)
                        }
                        if !vm.readings.isEmpty {
                            historySection
                        }
                    }
                    .padding(16)
                }
                .refreshable { await vm.loadReadings(forceRefresh: true) }
                if vm.isLoading && vm.readings.isEmpty {
                    ProgressView().tint(AppColor.primary)
                }
            }
            .navigationTitle("Blutzucker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if vm.fromCache {
                    ToolbarItem(placement: .topBarLeading) {
                        Image(systemName: "bolt.slash")
                            .foregroundStyle(AppColor.orange)
                            .font(.footnote)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.loadReadings(forceRefresh: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
        }
        .task { await vm.loadReadings() }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verlauf (letzte \(min(vm.readings.count, 20)) Messungen)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.muted)

            ForEach(vm.readings.reversed().prefix(20)) { reading in
                ReadingRow(reading: reading)
                Divider().background(AppColor.border)
            }
        }
    }
}

// MARK: - Subviews

private struct CurrentValueCard: View {
    let reading: GlucoseReading

    private var valueColor: Color {
        reading.isHigh ? AppColor.orange : reading.isLow ? AppColor.red : AppColor.green
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", reading.valueMmol))
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(valueColor)
                VStack(alignment: .leading) {
                    Text(reading.trendIcon)
                        .font(.system(size: 28))
                        .foregroundStyle(valueColor)
                    Text("mmol/L")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                }
            }
            Text("\(reading.valueMgDl) mg/dL")
                .font(.subheadline)
                .foregroundStyle(AppColor.muted)

            let (label, color) = reading.isHigh ? ("Zu hoch", AppColor.orange)
                               : reading.isLow  ? ("Zu tief", AppColor.red)
                                                : ("Im Bereich", AppColor.green)
            Text(label)
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(color)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColor.border, lineWidth: 1))
    }
}

private struct ReadingRow: View {
    let reading: GlucoseReading

    private var valueColor: Color {
        reading.isHigh ? AppColor.orange : reading.isLow ? AppColor.red : AppColor.text
    }

    var body: some View {
        HStack {
            Text(reading.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .frame(width: 55, alignment: .leading)
            Text(reading.displayValue)
                .font(.callout).fontWeight(.semibold)
                .foregroundStyle(valueColor)
            Text(reading.trendIcon)
                .foregroundStyle(AppColor.muted)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

private struct SyncInfo: View {
    let lastSync: Date
    let fromCache: Bool

    var body: some View {
        let diff = Int(Date().timeIntervalSince(lastSync) / 60)
        let label = diff < 1 ? "Gerade synchronisiert" : "Vor \(diff) Min. synchronisiert"
        HStack(spacing: 4) {
            Image(systemName: fromCache ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .font(.caption2)
            Text(label).font(.caption2)
        }
        .foregroundStyle(AppColor.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(AppColor.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppColor.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(AppColor.red.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Login View

private struct LibreLoginView: View {
    @Environment(LibreViewModel.self) private var vm
    @State private var email = ""
    @State private var password = ""
    @State private var region = LibreRegion.eu
    @State private var obscure = true

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Text("FreeStyle Libre")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(AppColor.text)
                    Text("LibreView-Zugangsdaten eingeben")
                        .font(.footnote)
                        .foregroundStyle(AppColor.muted)
                        .padding(.top, 6)

                    // E-Mail
                    InputField(text: $email, label: "E-Mail", systemIcon: "envelope")
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(.top, 32)

                    // Passwort
                    InputField(text: $password, label: "Passwort", systemIcon: "lock",
                               secure: obscure, trailing: {
                        Button { obscure.toggle() } label: {
                            Image(systemName: obscure ? "eye.slash" : "eye")
                                .foregroundStyle(AppColor.muted)
                        }
                    })
                    .padding(.top, 12)

                    // Region
                    Picker("Region", selection: $region) {
                        ForEach(LibreRegion.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                    // Login-Button
                    Button {
                        Task { await vm.login(email: email.trimmingCharacters(in: .whitespaces),
                                              password: password, region: region) }
                    } label: {
                        Group {
                            if vm.isLoading {
                                ProgressView().tint(AppColor.white)
                            } else {
                                Text("Verbinden").font(.system(size: 16, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .background(AppColor.primary)
                    .foregroundStyle(AppColor.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(vm.isLoading)
                    .padding(.top, 28)

                    if let error = vm.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppColor.red)
                            .padding(.top, 12)
                    }
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    GlucoseView()
        .environment(LibreViewModel())
}
