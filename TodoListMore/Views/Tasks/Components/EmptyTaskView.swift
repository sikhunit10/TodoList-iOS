//
//  EmptyTaskView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 24/03/25.
//

import SwiftUI

struct EmptyTaskView: View {
    var onAddTask: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding(.top, 40)
            
            Text("No Tasks")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("Tap the + button to add a new task")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                onAddTask()
            } label: {
                Text("Add Task")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}