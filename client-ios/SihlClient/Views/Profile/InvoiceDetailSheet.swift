import SwiftUI

/// Pendant zu `widgets/invoice_detail_sheet.dart`.
/// Wird als `.sheet(item:)` aus ProfileView geöffnet.
struct InvoiceDetailSheet: View {
    let invoice: Invoice
    @Environment(\.dismiss) private var dismiss

    @State private var qrData: Data?
    @State private var qrLoading = false
    @State private var qrError: String?

    private let svc = InvoiceService()

    private func fmt(_ date: Date?) -> String {
        date.map { SwissDay.display($0) } ?? "–"
    }

    /// Zahlungsweg nur für Lektionen vor Ort — Coaching-Rechnungen sind in
    /// der App reine Belege (App-Store 3.1.1/3.1.3(b)).
    private var showsPayment: Bool { !invoice.isPaid && !invoice.isCoaching }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.bottom, 20)

                    Divider().background(AppColor.border)
                        .padding(.bottom, 16)

                    detailRows
                        .padding(.bottom, 16)

                    if showsPayment {
                        paymentInfoBox
                            .padding(.bottom, 16)
                        qrBillSection
                    }
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, 20)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle("Rechnung \(invoice.invoiceNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(AppColor.primary)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            // Icon
            RoundedRectangle(cornerRadius: AppRadius.control)
                .fill(AppColor.primary.opacity(0.12))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "receipt")
                    .font(.app(20))
                    .foregroundStyle(AppColor.primary))

            // Number + Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Rechnung \(invoice.invoiceNumber)")
                    .font(.app(18, weight: .heavy))
                    .foregroundStyle(AppColor.text)
                statusBadge
            }

            Spacer()

            // Amount
            Text(invoice.amountFormatted)
                .font(.app(20, weight: .heavy))
                .foregroundStyle(AppColor.text)
        }
    }

    private var statusBadge: some View {
        let color = invoice.isPaid ? AppColor.green : AppColor.primary
        return Text(invoice.isPaid ? "Bezahlt" : "Offen")
            .font(.app(11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Detail Rows

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pkg = invoice.packageName, !pkg.isEmpty {
                DetailRow(label: "Position", value: pkg)
            }
            if !invoice.isCoaching, let c = invoice.credits, c > 0 {
                DetailRow(label: "Lektionen",
                          value: "\(c) \(c == 1 ? "Lektion" : "Lektionen")")
            }
            if let m = invoice.durationMonths {
                DetailRow(label: "Gültigkeit",
                          value: "\(m) \(m == 1 ? "Monat" : "Monate")")
            }
            DetailRow(label: "Rechnungsdatum", value: fmt(invoice.transactionDate))
            if !invoice.isCoaching {
                DetailRow(label: "Fällig am",   value: fmt(invoice.dueDate))
            }
        }
    }

    // MARK: - Payment Info Box

    private var paymentInfoBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Zahlungsinformationen")
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppColor.text)
            Text("Personal Training vor Ort\nJean Paul Mvongo, Personal Training\nVerwendungszweck: \(invoice.invoiceNumber)")
                .font(.app(12))
                .foregroundStyle(AppColor.muted)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
            .stroke(AppColor.primary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - QR Bill

    private var qrBillSection: some View {
        VStack(spacing: 12) {
            if qrData == nil && !qrLoading && qrError == nil {
                // "QR-Rechnung anzeigen" Button
                Button {
                    Task { await loadQr() }
                } label: {
                    Label("QR-Rechnung anzeigen", systemImage: "qrcode")
                        .font(.app(15, weight: .medium))
                        .foregroundStyle(AppColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                            .stroke(AppColor.primary.opacity(0.4), lineWidth: 1))
                }
            }

            if qrLoading {
                ProgressView().tint(AppColor.primary).padding(.vertical, 20)
            }

            if let err = qrError {
                VStack(spacing: 8) {
                    Text(err)
                        .font(.app(12))
                        .foregroundStyle(AppColor.muted)
                    Button {
                        Task { await loadQr() }
                    } label: {
                        Label("Erneut versuchen", systemImage: "arrow.clockwise")
                            .font(.app(14))
                            .foregroundStyle(AppColor.primary)
                    }
                }
            }

            if let imgData = qrData, let uiImg = UIImage(data: imgData) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(AppColor.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.control)
                        .stroke(AppColor.border, lineWidth: 1))
            }
        }
    }

    private func loadQr() async {
        qrLoading = true
        qrError   = nil
        do {
            if let d = try await svc.fetchQrBill(invoiceNumber: invoice.invoiceNumber) {
                qrData = d
            } else {
                qrError = "QR-Rechnung konnte nicht geladen werden."
            }
        } catch {
            qrError = "QR-Rechnung konnte nicht geladen werden."
        }
        qrLoading = false
    }
}

// MARK: - Detail Row (shared)

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.app(13))
                .foregroundStyle(AppColor.muted)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
