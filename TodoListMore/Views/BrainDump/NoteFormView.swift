//
//  NoteFormView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import SwiftUI
import CoreData
import AmplitudeSwift

struct NoteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var dataController: DataController
    
    @State private var content = ""
    @State private var tags = ""
    @State private var showingDeleteConfirmation = false
    
    let mode: NoteFormMode
    let onSave: () -> Void
    
    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var noteId: UUID? {
        if case .edit(let id) = mode {
            return UUID(uuidString: id)
        }
        return nil
    }
    
    init(mode: NoteFormMode, onSave: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Content editor
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Content")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your note...", text: $content, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(8...15)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Tags editor
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Add tags (comma separated)", text: $tags)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.white)
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadNoteData()
        }
        .alert("Delete Note", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("This will permanently delete this note. This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func loadNoteData() {
        guard let noteId = noteId else { return }
        
        let fetchRequest: NSFetchRequest<Note> = Note.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
        
        do {
            let notes = try viewContext.fetch(fetchRequest)
            if let note = notes.first {
                content = note.safeContent
                tags = note.safeTags
            }
        } catch {
            print("Error loading note: \(error.localizedDescription)")
        }
    }
    
    private func saveNote() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedContent.isEmpty else { return }
        
        let success: Bool
        
        if let noteId = noteId {
            // Update existing note
            success = dataController.updateNote(
                id: noteId,
                content: trimmedContent,
                tags: trimmedTags
            )
            
            if success {
                // Track note update
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.amplitude.track(
                    eventType: "note_updated",
                    eventProperties: [
                        "content_length": trimmedContent.count,
                        "has_tags": !trimmedTags.isEmpty
                    ]
                )
            }
        } else {
            // Create new note
            let note = dataController.addNote(
                content: trimmedContent,
                tags: trimmedTags
            )
            success = note != nil
            
            if success {
                // Track note creation
                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                appDelegate?.amplitude.track(
                    eventType: "note_created",
                    eventProperties: [
                        "content_length": trimmedContent.count,
                        "has_tags": !trimmedTags.isEmpty,
                        "creation_method": "form"
                    ]
                )
            }
        }
        
        if success {
            onSave()
            dismiss()
        }
    }
    
    private func deleteNote() {
        guard let noteId = noteId else { return }
        
        let success = dataController.deleteNote(id: noteId)
        
        if success {
            // Track note deletion
            let appDelegate = UIApplication.shared.delegate as? AppDelegate
            appDelegate?.amplitude.track(eventType: "note_deleted")
            
            dismiss()
        }
    }
}

// MARK: - NoteFormMode

enum NoteFormMode {
    case add
    case edit(String) // Note ID as string
}

#Preview {
    NoteFormView(mode: .add, onSave: {})
        .environmentObject(DataController.shared)
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}