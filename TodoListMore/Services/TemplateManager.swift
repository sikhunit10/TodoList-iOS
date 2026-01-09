//
//  TemplateManager.swift
//  TodoListMore
//
//  Created by Harjot Singh on 23/03/25.
//

import Foundation
import CoreData

class TemplateManager {
    static let shared = TemplateManager()
    
    private init() {}
    
    // MARK: - Built-in Templates
    
    func createBuiltInTemplates() {
        let dataController = DataController.shared
        
        // Check if built-in templates already exist
        let context = dataController.container.viewContext
        let fetchRequest: NSFetchRequest<TaskTemplate> = TaskTemplate.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isBuiltIn == YES")
        
        do {
            let existingTemplates = try context.fetch(fetchRequest)
            if !existingTemplates.isEmpty {
                print("DEBUG: Built-in templates already exist (\(existingTemplates.count) templates)")
                return
            }
        } catch {
            print("ERROR checking for existing templates: \(error)")
        }
        
        print("DEBUG: Creating built-in templates...")
        
        // Create built-in templates
        createTripPlanningTemplate()
        createWeeklyReviewTemplate()
        createProjectKickoffTemplate()
        createDailyRoutineTemplate()
        createMovingChecklistTemplate()
        createJobInterviewPrepTemplate()
        createEventPlanningTemplate()
        createHealthCheckupTemplate()
        
        print("DEBUG: Finished creating built-in templates")
    }
    
    private func createTripPlanningTemplate() {
        let tasks = [
            TemplateTaskData(title: "Research destination", description: "Look up attractions, weather, and local customs", priority: .high, dueDateOffset: -14),
            TemplateTaskData(title: "Book flights", description: "Compare prices and book airline tickets", priority: .high, dueDateOffset: -10),
            TemplateTaskData(title: "Book accommodation", description: "Reserve hotel or vacation rental", priority: .high, dueDateOffset: -10),
            TemplateTaskData(title: "Check passport/visa requirements", description: "Ensure documents are valid and up to date", priority: .high, dueDateOffset: -7),
            TemplateTaskData(title: "Create itinerary", description: "Plan daily activities and must-see places", priority: .medium, dueDateOffset: -7),
            TemplateTaskData(title: "Pack luggage", description: "Pack clothes and essentials for the trip", priority: .medium, dueDateOffset: -1),
            TemplateTaskData(title: "Check-in for flights", description: "Online check-in 24 hours before departure", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Notify bank of travel", description: "Inform bank to avoid card blocks abroad", priority: .low, dueDateOffset: -3)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Plan a Trip",
            description: "Complete checklist for planning your next vacation",
            category: "Travel",
            icon: "airplane",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createWeeklyReviewTemplate() {
        let tasks = [
            TemplateTaskData(title: "Review completed tasks", description: "Look back at what you accomplished this week", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Assess goals progress", description: "Check progress on monthly and quarterly goals", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Plan next week priorities", description: "Identify top 3 priorities for next week", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Clear inbox and notes", description: "Process emails, messages, and random notes", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Schedule important meetings", description: "Block time for important meetings and calls", priority: .medium, dueDateOffset: 1),
            TemplateTaskData(title: "Review calendar", description: "Check upcoming appointments and deadlines", priority: .low, dueDateOffset: 0)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Weekly Review",
            description: "Reflect on the past week and plan ahead",
            category: "Productivity",
            icon: "calendar",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createProjectKickoffTemplate() {
        let tasks = [
            TemplateTaskData(title: "Define project scope", description: "Clearly outline what the project will accomplish", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Identify stakeholders", description: "List all people involved or affected by the project", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Create project timeline", description: "Break down project into phases with deadlines", priority: .high, dueDateOffset: 1),
            TemplateTaskData(title: "Assign roles and responsibilities", description: "Define who is responsible for each task", priority: .medium, dueDateOffset: 2),
            TemplateTaskData(title: "Set up communication channels", description: "Establish how the team will communicate", priority: .medium, dueDateOffset: 1),
            TemplateTaskData(title: "Create project documentation", description: "Set up shared folders and documentation", priority: .medium, dueDateOffset: 2),
            TemplateTaskData(title: "Schedule kickoff meeting", description: "Organize meeting to launch the project", priority: .medium, dueDateOffset: 3),
            TemplateTaskData(title: "Identify risks and mitigation", description: "List potential risks and how to handle them", priority: .low, dueDateOffset: 2)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Project Kickoff",
            description: "Launch a new project with proper planning",
            category: "Work",
            icon: "rocket",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createDailyRoutineTemplate() {
        let tasks = [
            TemplateTaskData(title: "Morning exercise", description: "30 minutes of physical activity", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Review daily priorities", description: "Check schedule and identify top 3 tasks", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Check and respond to emails", description: "Process inbox and respond to important emails", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Lunch break", description: "Take a proper break for lunch", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Evening reflection", description: "Review the day and plan for tomorrow", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Read for 20 minutes", description: "Read a book or educational material", priority: .low, dueDateOffset: 0),
            TemplateTaskData(title: "Prepare for tomorrow", description: "Set out clothes and prepare for next day", priority: .low, dueDateOffset: 0)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Daily Routine",
            description: "Establish a productive daily routine",
            category: "Personal",
            icon: "sun.max",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createMovingChecklistTemplate() {
        let tasks = [
            TemplateTaskData(title: "Research moving companies", description: "Get quotes from 3+ moving companies", priority: .high, dueDateOffset: -30),
            TemplateTaskData(title: "Book moving company", description: "Schedule and confirm moving date", priority: .high, dueDateOffset: -21),
            TemplateTaskData(title: "Start decluttering", description: "Sort through belongings and donate/sell items", priority: .medium, dueDateOffset: -21),
            TemplateTaskData(title: "Change address", description: "Update address with bank, employer, subscriptions", priority: .high, dueDateOffset: -14),
            TemplateTaskData(title: "Pack non-essentials", description: "Pack items you won't need in the next 2 weeks", priority: .medium, dueDateOffset: -14),
            TemplateTaskData(title: "Transfer utilities", description: "Set up utilities at new address", priority: .high, dueDateOffset: -7),
            TemplateTaskData(title: "Pack essentials box", description: "Pack first-day essentials for new home", priority: .medium, dueDateOffset: -1),
            TemplateTaskData(title: "Confirm moving details", description: "Confirm time and logistics with movers", priority: .high, dueDateOffset: -1)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Moving Checklist",
            description: "Organized approach to moving to a new home",
            category: "Life Events",
            icon: "house",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createJobInterviewPrepTemplate() {
        let tasks = [
            TemplateTaskData(title: "Research the company", description: "Learn about company culture, values, and recent news", priority: .high, dueDateOffset: -3),
            TemplateTaskData(title: "Review job description", description: "Understand role requirements and responsibilities", priority: .high, dueDateOffset: -3),
            TemplateTaskData(title: "Prepare STAR examples", description: "Prepare Situation, Task, Action, Result examples", priority: .high, dueDateOffset: -2),
            TemplateTaskData(title: "Practice common questions", description: "Rehearse answers to common interview questions", priority: .medium, dueDateOffset: -2),
            TemplateTaskData(title: "Prepare questions to ask", description: "Prepare thoughtful questions about the role and company", priority: .medium, dueDateOffset: -1),
            TemplateTaskData(title: "Plan outfit and route", description: "Choose professional outfit and plan travel route", priority: .medium, dueDateOffset: -1),
            TemplateTaskData(title: "Print resume copies", description: "Print multiple copies of resume and references", priority: .low, dueDateOffset: -1),
            TemplateTaskData(title: "Send thank you note", description: "Send personalized thank you email within 24 hours", priority: .medium, dueDateOffset: 1)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Job Interview Prep",
            description: "Comprehensive preparation for job interviews",
            category: "Career",
            icon: "briefcase",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createEventPlanningTemplate() {
        let tasks = [
            TemplateTaskData(title: "Set event budget", description: "Determine total budget and allocate by category", priority: .high, dueDateOffset: -30),
            TemplateTaskData(title: "Choose venue", description: "Research and book event venue", priority: .high, dueDateOffset: -21),
            TemplateTaskData(title: "Create guest list", description: "Compile list of attendees and collect contact info", priority: .high, dueDateOffset: -21),
            TemplateTaskData(title: "Send invitations", description: "Send invites and track RSVPs", priority: .high, dueDateOffset: -14),
            TemplateTaskData(title: "Plan menu and catering", description: "Decide on food and drinks, book caterer if needed", priority: .medium, dueDateOffset: -14),
            TemplateTaskData(title: "Organize entertainment", description: "Book music, activities, or entertainment", priority: .medium, dueDateOffset: -7),
            TemplateTaskData(title: "Prepare decorations", description: "Buy or make decorations for the event", priority: .low, dueDateOffset: -3),
            TemplateTaskData(title: "Final headcount", description: "Confirm final number of attendees", priority: .medium, dueDateOffset: -1)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Event Planning",
            description: "Organize a memorable event from start to finish",
            category: "Social",
            icon: "party.popper",
            tasks: tasks,
            isBuiltIn: true
        )
    }
    
    private func createHealthCheckupTemplate() {
        let tasks = [
            TemplateTaskData(title: "Schedule annual physical", description: "Book appointment with primary care doctor", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Schedule dental cleaning", description: "Book routine dental cleaning and checkup", priority: .high, dueDateOffset: 0),
            TemplateTaskData(title: "Schedule eye exam", description: "Book annual eye examination", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Update emergency contacts", description: "Review and update emergency contact information", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Review medications", description: "Check current medications with doctor", priority: .medium, dueDateOffset: 0),
            TemplateTaskData(title: "Update health insurance", description: "Review and update health insurance information", priority: .low, dueDateOffset: 0),
            TemplateTaskData(title: "Schedule preventive screenings", description: "Book age-appropriate health screenings", priority: .medium, dueDateOffset: 0)
        ]
        
        _ = DataController.shared.createTemplate(
            name: "Health Checkup",
            description: "Stay on top of your health with regular checkups",
            category: "Health",
            icon: "stethoscope",
            tasks: tasks,
            isBuiltIn: true
        )
    }
}