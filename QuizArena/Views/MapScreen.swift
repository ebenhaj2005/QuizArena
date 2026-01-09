import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
    @StateObject private var loc = LocationService()
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            // Map
            Map(position: $camera) {
                if let l = loc.location {
                    Annotation("Jouw locatie", coordinate: l.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 24, height: 24)
                            
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top status card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.blue)
                        Text("Kaart")
                            .font(.headline)
                        Spacer()
                    }
                    
                    if let err = loc.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10)
                .padding()
                
                Spacer()
                
                // Bottom info card
                Group {
                    if loc.authorization == .notDetermined {
                        LocationPermissionCard {
                            loc.requestPermission()
                        }
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                    } else if loc.authorization == .denied || loc.authorization == .restricted {
                        LocationDeniedCard()
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                    } else if let l = loc.location {
                        LocationInfoCard(location: l)
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                    } else {
                        LoadingLocationCard()
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .navigationTitle("Kaart")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🗺️ MapScreen appeared")
            loc.start()
        }
        .onDisappear {
            print("🗺️ MapScreen disappeared")
            loc.stop()
        }
        .onChange(of: loc.location) { oldVal, newVal in
            guard let c = newVal?.coordinate else { return }
            print("🗺️ Camera updating to: \(c.latitude), \(c.longitude)")
            
            withAnimation {
                camera = .region(
                    MKCoordinateRegion(
                        center: c,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
}

struct LocationPermissionCard: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            VStack(spacing: 8) {
                Text("Locatie Toegang Nodig")
                    .font(.headline)
                
                Text("We hebben toegang tot je locatie nodig om de kaart te tonen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: action) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Locatie Toestaan")
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
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 15)
    }
}

struct LocationDeniedCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            
            VStack(spacing: 8) {
                Text("Locatie Uitgeschakeld")
                    .font(.headline)
                
                Text("Ga naar Instellingen > QuizArena > Locatie om toegang te geven")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Instellingen")
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
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 15)
    }
}

struct LocationInfoCard: View {
    let location: CLLocation
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
                Text("Locatie Gevonden")
                    .font(.headline)
                Spacer()
            }
            
            Divider()
            
            VStack(spacing: 8) {
                InfoRow(
                    icon: "map.fill",
                    title: "Latitude",
                    value: String(format: "%.6f°", location.coordinate.latitude)
                )
                
                InfoRow(
                    icon: "map.fill",
                    title: "Longitude",
                    value: String(format: "%.6f°", location.coordinate.longitude)
                )
                
                InfoRow(
                    icon: "scope",
                    title: "Nauwkeurigheid",
                    value: "±\(Int(location.horizontalAccuracy))m"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

struct LoadingLocationCard: View {
    var body: some View {
        HStack(spacing: 16) {
            ProgressView()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Locatie Ophalen...")
                    .font(.headline)
                Text("Even geduld aub")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
    }
}
