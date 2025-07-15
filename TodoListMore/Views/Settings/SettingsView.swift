//
//  SettingsView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import AmplitudeSwift

struct SettingsView: View {
    @EnvironmentObject private var dataController: DataController
    
    @State private var showingDeleteConfirmation = false
    @State private var showDeleteCompletedConfirmation = false
    @State private var showingAlert = false
    @State private var alertTitle = "Error"
    @State private var alertMessage = ""
    @State private var showOnboarding = false
    @Binding var tabSelection: Int
    
    @AppStorage("completedTasksVisible") private var completedTasksVisible = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // Get app version from Info.plist
    private var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // Default initializer for previews
    init() {
        self._tabSelection = .constant(3)
    }
    
    // Initializer with tab binding
    init(tabSelection: Binding<Int>) {
        self._tabSelection = tabSelection
    }
    
    var body: some View {
        SettingsListContent()
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .toolbar {
                // Empty toolbar to maintain consistent appearance
                ToolbarItem(placement: .navigationBarTrailing) {
                    Spacer()
                }
            }
            // Delete all data confirmation
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all tasks and categories. This action cannot be undone.")
            }
            // Delete completed tasks confirmation
            .alert("Delete Completed Tasks", isPresented: $showDeleteCompletedConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCompletedTasks()
                }
            } message: {
                Text("This will permanently delete all completed tasks. This action cannot be undone.")
            }
            // Alert for errors or success messages
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func SettingsListContent() -> some View {
        List {
            // APPEARANCE SECTION
            AppearanceSection
            
            // DATA MANAGEMENT SECTION
            DataManagementSection
            
            // ABOUT SECTION
            AboutSection
        }
    }
    
    private var AppearanceSection: some View {
        Section {
            // App appearance
            Toggle("Show Completed Tasks", isOn: $completedTasksVisible)
        } header: {
            Text("Appearance")
        } footer: {
            Text("When disabled, completed tasks will be hidden from the task list.")
        }
    }
    
    private var DataManagementSection: some View {
        Section {
            // Button to delete all completed tasks
            Button {
                showDeleteCompletedConfirmation = true
            } label: {
                Label("Delete Completed Tasks", systemImage: "checkmark.circle")
                    .foregroundColor(.orange)
            }
            
            // Button to delete all data
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
                    .foregroundColor(.red)
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("These actions cannot be undone.")
        }
    }
    
    private var AboutSection: some View {
        Section {
            // Show Onboarding Again
            Button {
                showOnboarding = true
            } label: {
                Label("Show App Introduction", systemImage: "play.circle")
            }
            
            // Version info
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }
            
            // Privacy Policy link
            Link(destination: URL(string: "https://harjotsinghpanesar.com/privacy_policy")!) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
            
            // Support link
            Link(destination: URL(string: "https://harjotsinghpanesar.com/contact")!) {
                HStack {
                    Label("Support", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
            }
        } header: {
            Text("About")
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(tabSelection: $tabSelection)
        }
    }
    
    // MARK: - Private Methods
    
    private func deleteAllData() {
        // Delete all tasks
        let taskFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Task")
        let taskDeleteRequest = NSBatchDeleteRequest(fetchRequest: taskFetchRequest)
        
        // Delete all categories
        let categoryFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Category")
        let categoryDeleteRequest = NSBatchDeleteRequest(fetchRequest: categoryFetchRequest)
        
        let context = dataController.container.viewContext
        
        do {
            try context.execute(taskDeleteRequest)
            try context.execute(categoryDeleteRequest)
            
            // Save changes
            dataController.save()
            
            // Track data deletion
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(eventType: "delete_all_data")
            
            // Show success message
            alertTitle = "Success"
            alertMessage = "All data has been successfully deleted."
            showingAlert = true
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to delete data: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func deleteCompletedTasks() {
        // Use the batch delete function from DataController
        let deletedCount = dataController.deleteAllCompletedTasks()
        
        // Track completed tasks deletion
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.amplitude.track(
            eventType: "delete_completed_tasks",
            eventProperties: ["count": deletedCount]
        )
        
        if deletedCount == 0 {
            alertTitle = "Information"
            alertMessage = "No completed tasks found to delete."
            showingAlert = true
        } else {
            // Show a success message with count
            alertTitle = "Success"
            alertMessage = "\(deletedCount) completed \(deletedCount == 1 ? "task" : "tasks") successfully deleted."
            showingAlert = true
        }
    }
}
