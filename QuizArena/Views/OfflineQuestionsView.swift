import SwiftUI
import CoreData

struct OfflineQuestionsView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var vm = OfflineQuestionsViewModel()

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Offline Modus")
                            .font(.title.bold())
                        
                        Text("Speel zonder internet verbinding")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    // Error message
                    if let err = vm.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Status card
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Status")
                                .font(.headline)
                            Spacer()
                        }
                        
                        VStack(spacing: 12) {
                            StatusRow(
                                icon: vm.isOffline ? "checkmark.circle.fill" : "xmark.circle.fill",
                                title: "Modus",
                                value: vm.isOffline ? "OFFLINE" : "ONLINE",
                                color: vm.isOffline ? .orange : .green
                            )
                            
                            Divider()
                            
                            StatusRow(
                                icon: "clock.fill",
                                title: "Laatste update",
                                value: vm.lastUpdatedText,
                                color: .blue
                            )
                            
                            Divider()
                            
                            StatusRow(
                                icon: "list.bullet",
                                title: "Vragen in cache",
                                value: "\(vm.rows.count)",
                                color: .purple
                            )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    // Questions list
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Offline Vragen")
                                .font(.headline)
                            Spacer()
                        }
                        
                        if vm.rows.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                
                                Text("Geen offline vragen beschikbaar")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text("Druk op 'Vernieuwen' om vragen te downloaden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(vm.rows) { row in
                                    QuestionCard(question: row.question, savedAt: row.savedAt)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            Task { await vm.refreshFromWeb(context: context, amount: 10) }
                        } label: {
                            HStack {
                                if vm.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(vm.isLoading ? "Laden..." : "Vernieuwen")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(vm.isLoading)
                        
                        Button(role: .destructive) {
                            vm.clearCache(context: context)
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Wis Cache")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Offline Vragen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.loadFromCache(context: context)
        }
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 30)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

struct QuestionCard: View {
    let question: String
    let savedAt: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(savedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}
