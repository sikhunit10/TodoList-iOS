//
//  EmptyTaskView.swift
//  TodoListMore
//
//  Created by Harjot Singh on 24/03/25.
//

import SwiftUI

struct EmptyTaskView: View {
    var onAddTask: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private let accentColor = Color(hex: "#5D4EFF")
    
    var body: some View {
        VStack(spacing: 24) {
            // Modern illustration style icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checklist.checked")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(accentColor)
            }
            .padding(.top, 60)
            
            VStack(spacing: 12) {
                Text("No Tasks Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Create your first task to get started with organizing your day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button {
                onAddTask()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    
                    Text("Create Task")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(accentColor)
                .foregroundColor(.white)
                .cornerRadius(30)
            }
            .buttonStyle(ScaleButtonStyle())
            .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.top, 16)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}