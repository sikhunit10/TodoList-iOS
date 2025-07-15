//
//  BrainDumpView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import AmplitudeSwift

struct BrainDumpView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var searchText = ""
    @State private var showingNoteForm = false
    @State private var selectedNoteId: String? = nil
    @State private var quickNoteText = ""
    @FocusState private var isQuickNoteActive: Bool
    
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Note.dateModified, order: .reverse)],
        animation: .default
    ) private var notes: FetchedResults<Note>
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return Array(notes)
        } else {
            return notes.filter { note in
                note.safeContent.localizedCaseInsensitiveContains(searchText) ||
                note.safeTags.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Quick note input
                quickNoteInput
                
                // Notes list
                notesList
            }
            .background(Color.white)
            
            // Floating add button
            FloatingAddButton {
                showingNoteForm = true
            }
        }
        .navigationTitle("Brain Dump")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search notes")
        .sheet(isPresented: $showingNoteForm) {
            NavigationStack {
                NoteFormView(mode: .add, onSave: {})
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedNoteId) { noteId in
            NavigationStack {
                NoteFormView(mode: .edit(noteId), onSave: {})
            }
            .presentationDetents([.medium, .large])
            .onDisappear {
                selectedNoteId = nil
            }
        }
        .onAppear {
            // Track screen view
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(eventType: "view_brain_dump_screen")
        }
    }
    
    // MARK: - View Components
    
    private var quickNoteInput: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Quick note...", text: $quickNoteText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .focused($isQuickNoteActive)
                    .onSubmit {
                        saveQuickNote()
                    }
                
                Button(action: saveQuickNote) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(quickNoteText.isEmpty ? .gray : Color(hex: "#5D4EFF"))
                }
                .disabled(quickNoteText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color.white)
    }
    
    private var notesList: some View {
        List {
            if filteredNotes.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredNotes, id: \.id) { note in
                    NoteRowView(note: note) {
                        selectedNoteId = note.id?.uuidString
                    }
                }
                .onDelete(perform: deleteNotes)
                
                // Bottom spacer for floating button
                Color.clear
                    .frame(height: 76)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.white)
            }
        }
        .listStyle(.plain)
        .background(Color.white)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No notes yet")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                Text("Capture your thoughts and ideas here. Start by typing in the quick note field above or tap the + button.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.white)
    }
    
    // MARK: - Actions
    
    private func saveQuickNote() {
        guard !quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let content = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = dataController.addNote(content: content)
        
        // Track quick note creation
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.amplitude.track(
            eventType: "quick_note_created",
            eventProperties: ["content_length": content.count]
        )
        
        // Clear the input
        quickNoteText = ""
        isQuickNoteActive = false
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let note = filteredNotes[index]
                if let noteId = note.id {
                    _ = dataController.deleteNote(id: noteId)
                    
                    // Track note deletion
                    let appDelegate = UIApplication.shared.delegate as? AppDelegate
                    appDelegate?.amplitude.track(eventType: "note_deleted")
                }
            }
        }
    }
}

// MARK: - NoteRowView

struct NoteRowView: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Content preview
                Text(note.preview)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                // Metadata
                HStack {
                    Text(note.formattedDateModified)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !note.safeTags.isEmpty {
                        Text(note.safeTags)
                            .font(.caption)
                            .foregroundColor(Color(hex: "#5D4EFF"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#5D4EFF").opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.white)
    }
}

// MARK: - Extensions

#Preview {
    BrainDumpView()
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}