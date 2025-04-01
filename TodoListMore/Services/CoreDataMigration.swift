//
//  CoreDataMigration.swift
//  TodoListMore
//
//  Created by Harjot Singh on 31/03/25.
//

import CoreData
import Foundation

// This class provides helper functions for checking if reminder attributes exist and handling their absence
class CoreDataMigration {
    static let shared = CoreDataMigration()
    
    private init() {}
    
    // Check if the reminder attributes exist in the Task entity
    func hasReminderAttributes(viewContext: NSManagedObjectContext) -> Bool {
        guard let entity = NSEntityDescription.entity(forEntityName: "Task", in: viewContext) else {
            return false
        }
        
        // Check if attributes exist in the model
        let hasAttributes = entity.attributesByName["reminderType"] != nil && 
                           entity.attributesByName["customReminderTime"] != nil
        
        // Double check with a test instance to be absolutely sure
        if hasAttributes {
            // Create a test instance to verify KVC access works
            do {
                let testInstance = NSEntityDescription.insertNewObject(forEntityName: "Task", into: viewContext)
                // Try setting a value
                testInstance.setValue(0, forKey: "reminderType")
                testInstance.setValue(0.0, forKey: "customReminderTime")
                // If we got here, the attributes exist and are accessible
                viewContext.delete(testInstance) // Clean up
                
                // Since we've verified the attributes exist, return true and log success
                print("✅ Reminder attributes verified in Core Data model")
                return true
            } catch {
                print("❌ Error verifying reminder attributes: \(error.localizedDescription)")
                return false
            }
        } else {
            print("❌ Reminder attributes not found in Core Data model")
        }
        
        return false
    }
    
    // Print a message to the developer about adding reminder attributes
    func printMigrationInstructions() {
        print("""
        ⚠️ Reminder attributes not found in Task entity.
        
        To add reminder functionality, you need to manually update the Core Data model:
        1. Open TodoListMore.xcdatamodeld in Xcode
        2. Select the Task entity
        3. Add these attributes:
           - reminderType (Int16, optional)
           - customReminderTime (Double, optional)
        4. Generate a model version and migration if needed
        
        Until then, reminder functionality will be disabled.
        """)
    }
}