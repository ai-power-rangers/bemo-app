//
//  TangramDatabaseLoader.swift
//  Bemo
//
//  Loads tangram puzzles from Supabase database without editor dependencies
//

// WHAT: Self-contained database loader for Tangram game puzzles
// ARCHITECTURE: Service in MVVM-S, connects to Supabase for puzzle data
// USAGE: Load cat and rocket ship puzzles from database

import Foundation
import SwiftUI

/// Loads tangram puzzles from database without depending on editor types
class TangramDatabaseLoader {
    
    private let supabaseService: SupabaseService?
    
    init(supabaseService: SupabaseService? = nil) {
        self.supabaseService = supabaseService
    }
    
    /// Load all official puzzles from database
    func loadOfficialPuzzles() async throws -> [GamePuzzleData] {
        guard let supabase = supabaseService else {
            print("Warning: No Supabase service available")
            return []
        }
        
        do {
            // Fetch all official puzzles from database using the correct method name
            let dtos = try await supabase.fetchOfficialTangramPuzzles()
            
            var puzzles: [GamePuzzleData] = []
            
            for dto in dtos {
                // Extract the puzzle data from the JSONB field
                var puzzleDict: [String: Any]?
                
                // Check if puzzle_data.value is a String (JSON string) or already a Dictionary
                if let jsonString = dto.puzzle_data.value as? String {
                    // Parse the JSON string to dictionary
                    if let data = jsonString.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        puzzleDict = parsed
                    }
                } else if let dict = dto.puzzle_data.value as? [String: Any] {
                    // Already a dictionary
                    puzzleDict = dict
                }
                
                if let puzzleDict = puzzleDict,
                   let gamePuzzle = PuzzleDataConverter.convertFromDatabase(puzzleDict) {
                    puzzles.append(gamePuzzle)
                    print("Loaded puzzle: \(gamePuzzle.name)")
                }
            }
            
            return puzzles
        } catch {
            print("Error loading puzzles from database: \(error)")
            throw error
        }
    }
    
    /// Load specific puzzle by ID
    func loadPuzzle(id: String) async throws -> GamePuzzleData? {
        guard let supabase = supabaseService else {
            print("Warning: No Supabase service available")
            return nil
        }
        
        do {
            // For now, load all puzzles and find the one with matching ID
            // Since there's no fetchTangramPuzzle(puzzleId:) method in SupabaseService
            let dtos = try await supabase.fetchOfficialTangramPuzzles()
            
            for dto in dtos {
                if dto.puzzle_id == id {
                    // Extract the puzzle data from the JSONB field
                    var puzzleDict: [String: Any]?
                    
                    // Check if puzzle_data.value is a String (JSON string) or already a Dictionary
                    if let jsonString = dto.puzzle_data.value as? String {
                        // Parse the JSON string to dictionary
                        if let data = jsonString.data(using: .utf8),
                           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            puzzleDict = parsed
                        }
                    } else if let dict = dto.puzzle_data.value as? [String: Any] {
                        // Already a dictionary
                        puzzleDict = dict
                    }
                    
                    if let puzzleDict = puzzleDict {
                        return PuzzleDataConverter.convertFromDatabase(puzzleDict)
                    }
                }
            }
            
            return nil
        } catch {
            print("Error loading puzzle \(id): \(error)")
            throw error
        }
    }
    
    /// Load puzzles by category
    func loadPuzzlesByCategory(_ category: String) async throws -> [GamePuzzleData] {
        guard let supabase = supabaseService else {
            print("Warning: No Supabase service available")
            return []
        }
        
        do {
            let dtos = try await supabase.fetchTangramPuzzlesByCategory(category)
            
            var puzzles: [GamePuzzleData] = []
            
            for dto in dtos {
                // Extract the puzzle data from the JSONB field
                var puzzleDict: [String: Any]?
                
                // Check if puzzle_data.value is a String (JSON string) or already a Dictionary
                if let jsonString = dto.puzzle_data.value as? String {
                    // Parse the JSON string to dictionary
                    if let data = jsonString.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        puzzleDict = parsed
                    }
                } else if let dict = dto.puzzle_data.value as? [String: Any] {
                    // Already a dictionary
                    puzzleDict = dict
                }
                
                if let puzzleDict = puzzleDict,
                   let gamePuzzle = PuzzleDataConverter.convertFromDatabase(puzzleDict) {
                    puzzles.append(gamePuzzle)
                }
            }
            
            return puzzles
        } catch {
            print("Error loading puzzles for category \(category): \(error)")
            throw error
        }
    }
}