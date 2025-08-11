//
//  PuzzleDataConverter.swift
//  Bemo
//
//  Converts database puzzle data to game format without editor dependencies
//

// WHAT: Handles conversion from database format to GamePuzzleData
// ARCHITECTURE: Service layer converter for data transformation
// USAGE: Called when loading puzzles from database to convert to game format

import Foundation
import CoreGraphics

/// Error types for puzzle data conversion
enum PuzzleDataConverterError: Error {
    case missingRequiredFields(fields: [String])
    case invalidPieceType(type: String)
    case missingTransformData
    case invalidDataFormat
}

/// Converts puzzle data from various sources to GamePuzzleData format
enum PuzzleDataConverter {
    
    /// Convert from database JSON/Dictionary format
    static func convertFromDatabase(_ data: [String: Any]) -> Result<GamePuzzleData, PuzzleDataConverterError> {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String else {
            return .failure(.missingRequiredFields(fields: ["id", "name"]))
        }
        
        // Category and difficulty might be nested or as raw values
        let category = (data["category"] as? [String: Any])?["rawValue"] as? String ?? 
                      data["category"] as? String ?? "Unknown"
        
        let difficulty = (data["difficulty"] as? [String: Any])?["rawValue"] as? Int ?? 
                        data["difficulty"] as? Int ?? 1
        
        // Parse pieces array
        guard let piecesData = data["pieces"] as? [[String: Any]] else {
            return .failure(.missingRequiredFields(fields: ["pieces"]))
        }
        
        let targetPieces = piecesData.compactMap { pieceDict -> GamePuzzleData.TargetPiece? in
            // Get piece type
            let typeRawValue = (pieceDict["type"] as? [String: Any])?["rawValue"] as? String ?? 
                              pieceDict["type"] as? String ?? ""
            
            guard let pieceType = TangramPieceType(rawValue: typeRawValue) else {
                // Log error in debug builds only
                #if DEBUG
                print("Warning: Unknown piece type: \(typeRawValue)")
                #endif
                return nil
            }
            
            // Get transform - it might be nested
            var transformDict: [String: Double]?
            if let transform = pieceDict["transform"] as? [String: Any] {
                // Convert Any values to Double
                transformDict = [:]
                for (key, value) in transform {
                    if let doubleValue = value as? Double {
                        transformDict?[key] = doubleValue
                    } else if let floatValue = value as? Float {
                        transformDict?[key] = Double(floatValue)
                    } else if let intValue = value as? Int {
                        transformDict?[key] = Double(intValue)
                    }
                }
            }
            
            guard let transform = transformDict else {
                #if DEBUG
                print("Warning: No transform data for piece")
                #endif
                return nil
            }
            
            // Extract piece ID (use piece type as fallback if not present)
            let pieceId = pieceDict["id"] as? String ?? UUID().uuidString
            
            // Reconstruct CGAffineTransform from components
            let affineTransform = CGAffineTransform(
                a: CGFloat(transform["a"] ?? 1),
                b: CGFloat(transform["b"] ?? 0),
                c: CGFloat(transform["c"] ?? 0),
                d: CGFloat(transform["d"] ?? 1),
                tx: CGFloat(transform["tx"] ?? 0),
                ty: CGFloat(transform["ty"] ?? 0)
            )
            
            return GamePuzzleData.TargetPiece(
                id: pieceId,
                pieceType: pieceType,
                transform: affineTransform
            )
        }
        
        guard !targetPieces.isEmpty else {
            return .failure(.invalidDataFormat)
        }
        
        return .success(GamePuzzleData(
            id: id,
            name: name,
            category: category,
            difficulty: difficulty,
            targetPieces: targetPieces
        ))
    }
    
    /// Convert from Codable data (when we have proper types)
    static func convertFromCodable<T: Decodable>(_ data: T) -> GamePuzzleData? {
        // This will handle conversion from any Codable puzzle format
        // For now, using mirror to extract properties dynamically
        let mirror = Mirror(reflecting: data)
        
        var dict: [String: Any] = [:]
        for child in mirror.children {
            if let label = child.label {
                dict[label] = child.value
            }
        }
        
        switch convertFromDatabase(dict) {
        case .success(let puzzle):
            return puzzle
        case .failure:
            return nil
        }
    }
    
}