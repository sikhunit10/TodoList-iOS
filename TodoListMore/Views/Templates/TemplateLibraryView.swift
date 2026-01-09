//
//  TemplateLibraryView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import AmplitudeSwift

struct TemplateLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataController: DataController
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingTemplateForm = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var showingTemplatePreview = false
    
    @FetchRequest(
        sortDescriptors: [
            SortDescriptor(\TaskTemplate.category, order: .forward),
            SortDescriptor(\TaskTemplate.isBuiltIn, order: .reverse),
            SortDescriptor(\TaskTemplate.name, order: .forward)
        ],
        animation: .default
    ) private var templates: FetchedResults<TaskTemplate>
    
    private var categories: [String] {
        let allCategories = Set(templates.map { $0.safeCategory })
        return ["All"] + Array(allCategories).sorted()
    }
    
    private var filteredTemplates: [TaskTemplate] {
        var filtered = Array(templates)
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.safeCategory == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { template in
                template.safeName.localizedCaseInsensitiveContains(searchText) ||
                template.safeDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    private var groupedTemplates: [String: [TaskTemplate]] {
        Dictionary(grouping: filteredTemplates) { $0.safeCategory }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                categoryFilter
                
                // Templates list
                templatesList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingTemplateForm = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#5D4EFF"))
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search templates")
            .sheet(isPresented: $showingTemplateForm) {
                TemplateFormView(mode: .create, onSave: {})
            }
            .sheet(item: $selectedTemplate) { template in
                TemplatePreviewView(template: template)
            }
        }
        .onAppear {
            // Track template library view
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(eventType: "view_template_library")
        }
    }
    
    // MARK: - View Components
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedCategory == category ? .white : Color(hex: "#5D4EFF"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == category ? Color(hex: "#5D4EFF") : Color.clear)
                                    .stroke(Color(hex: "#5D4EFF"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    private var templatesList: some View {
        List {
            if filteredTemplates.isEmpty {
                emptyStateView
            } else {
                ForEach(groupedTemplates.keys.sorted(), id: \.self) { category in
                    if selectedCategory == "All" {
                        Section(header: Text(category)) {
                            ForEach(groupedTemplates[category] ?? [], id: \.id) { template in
                                TemplateRowView(template: template, showCategory: false) {
                                    selectedTemplate = template
                                }
                            }
                            .onDelete { indexSet in
                                deleteTemplates(in: category, at: indexSet)
                            }
                        }
                    } else {
                        ForEach(groupedTemplates[category] ?? [], id: \.id) { template in
                            TemplateRowView(template: template, showCategory: true) {
                                selectedTemplate = template
                            }
                        }
                        .onDelete { indexSet in
                            deleteTemplates(in: category, at: indexSet)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No templates found")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            
            if !searchText.isEmpty {
                Text("Try adjusting your search or browse different categories.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                Text("Create your first template to get started with recurring workflows.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    showingTemplateForm = true
                }) {
                    Text("Create Template")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#5D4EFF"))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Actions
    
    private func deleteTemplates(in category: String, at offsets: IndexSet) {
        let templatesInCategory = groupedTemplates[category] ?? []
        
        for index in offsets {
            let template = templatesInCategory[index]
            
            // Don't allow deleting built-in templates
            if template.isBuiltIn {
                continue
            }
            
            if let templateId = template.id {
                _ = dataController.deleteTemplate(id: templateId)
                
                // Track template deletion
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.amplitude.track(
                    eventType: "template_deleted",
                    eventProperties: ["template_name": template.safeName]
                )
            }
        }
    }
}

// MARK: - TemplateRowView

struct TemplateRowView: View {
    let template: TaskTemplate
    let showCategory: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: template.safeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#5D4EFF"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "#5D4EFF").opacity(0.1))
                    .cornerRadius(8)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(template.safeName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if template.isBuiltIn {
                            Text("Built-in")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    
                    if !template.safeDescription.isEmpty {
                        Text(template.safeDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("\(template.templateTasksArray.count) tasks")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if showCategory {
                            Text(template.safeCategory)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#5D4EFF"))
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TemplateLibraryView()
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}