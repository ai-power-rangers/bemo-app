//
//  TangramPuzzle.swift
//  Bemo
//
//  Complete puzzle definition for target shapes
//

import Foundation

struct TangramPuzzle: Codable, Identifiable {
    let id: String
    var name: String
    var category: String
    var difficulty: Difficulty
    var pieces: [TangramPiece]
    var connections: [Connection]
    var solutionChecksum: String
    let createdDate: Date
    var modifiedDate: Date
    var createdBy: String?
    var thumbnailData: Data?
    var tags: [String]
    
    enum Difficulty: Int, Codable, CaseIterable {
        case beginner = 1
        case easy = 2
        case medium = 3
        case hard = 4
        case expert = 5
        
        var displayName: String {
            switch self {
            case .beginner: return "Beginner"
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            case .expert: return "Expert"
            }
        }
    }
    
    enum Category: String, Codable, CaseIterable {
        case animals = "Animals"
        case people = "People"
        case objects = "Objects"
        case letters = "Letters"
        case numbers = "Numbers"
        case geometric = "Geometric"
        case abstract = "Abstract"
        case custom = "Custom"
    }
    
    init(
        name: String,
        category: String = Category.custom.rawValue,
        difficulty: Difficulty = .medium,
        createdBy: String? = nil
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.difficulty = difficulty
        self.pieces = []
        self.connections = []
        self.solutionChecksum = ""
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.createdBy = createdBy
        self.tags = []
    }
    
    mutating func addPiece(_ piece: TangramPiece) {
        pieces.append(piece)
        modifiedDate = Date()
        updateSolutionChecksum()
    }
    
    mutating func removePiece(id: String) {
        pieces.removeAll { $0.id == id }
        connections.removeAll { connection in
            switch connection.type {
            case .vertexToVertex(let pieceA, _, let pieceB, _),
                 .edgeToEdge(let pieceA, _, let pieceB, _):
                return pieceA == id || pieceB == id
            }
        }
        modifiedDate = Date()
        updateSolutionChecksum()
    }
    
    mutating func updatePiece(_ piece: TangramPiece) {
        if let index = pieces.firstIndex(where: { $0.id == piece.id }) {
            pieces[index] = piece
            modifiedDate = Date()
            updateSolutionChecksum()
        }
    }
    
    mutating func addConnection(_ connection: Connection) {
        connections.append(connection)
        modifiedDate = Date()
    }
    
    mutating func removeConnection(id: String) {
        connections.removeAll { $0.id == id }
        modifiedDate = Date()
    }
    
    private mutating func updateSolutionChecksum() {
        var checksumString = ""
        
        let sortedPieces = pieces.sorted { $0.id < $1.id }
        for piece in sortedPieces {
            checksumString += "\(piece.type.displayName)"
            checksumString += "|\(piece.currentTransform.a),\(piece.currentTransform.b)"
            checksumString += ",\(piece.currentTransform.c),\(piece.currentTransform.d)"
            checksumString += ",\(piece.currentTransform.tx),\(piece.currentTransform.ty)|"
        }
        
        if let data = checksumString.data(using: .utf8) {
            let hash = data.base64EncodedString()
            solutionChecksum = String(hash.prefix(16))
        }
    }
    
    func validate() -> ValidationResult {
        var errors: [String] = []
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Puzzle name is required")
        }
        
        if pieces.isEmpty {
            errors.append("Puzzle must contain at least one piece")
        }
        
        let allPieceTypes = TangramPieceGeometry.PieceType.allCases
        let usedTypes = pieces.map { $0.type }
        
        if pieces.count > 7 {
            errors.append("Puzzle cannot contain more than 7 pieces")
        }
        
        var typeCount: [TangramPieceGeometry.PieceType: Int] = [:]
        for type in usedTypes {
            typeCount[type, default: 0] += 1
        }
        
        for (type, count) in typeCount {
            let maxAllowed: Int
            switch type {
            case .smallTriangle1, .smallTriangle2, .largeTriangle1, .largeTriangle2:
                maxAllowed = 2
            default:
                maxAllowed = 1
            }
            
            if count > maxAllowed {
                errors.append("Too many \(type.displayName) pieces (max \(maxAllowed))")
            }
        }
        
        let connectionSystem = ConnectionSystem()
        for piece in pieces {
            connectionSystem.addPiece(
                id: piece.id,
                type: piece.type,
                transform: piece.currentTransform
            )
        }
        
        for connection in connections {
            _ = connectionSystem.createConnection(type: connection.type)
        }
        
        if connectionSystem.hasInvalidAreaOverlaps() {
            errors.append("Pieces have area overlap")
        }
        
        if connectionSystem.hasUnexplainedContacts() {
            errors.append("Pieces touch without declared connection")
        }
        
        if pieces.count > 1 && !connectionSystem.isConnected() {
            errors.append("All pieces must be connected")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    struct ValidationResult {
        let isValid: Bool
        let errors: [String]
    }
}

extension TangramPuzzle {
    func exportAsSolved() -> SolvedTangramPuzzle {
        let solvedPieces = pieces.map { piece in
            SolvedPiece(
                pieceType: piece.type,
                transform: piece.currentTransform
            )
        }
        
        return SolvedTangramPuzzle(
            id: id,
            name: name,
            difficulty: difficulty.rawValue,
            solvedPieces: solvedPieces
        )
    }
}

struct SolvedTangramPuzzle: Codable {
    let id: String
    let name: String
    let difficulty: Int
    let solvedPieces: [SolvedPiece]
}

struct SolvedPiece: Codable {
    let pieceType: TangramPieceGeometry.PieceType
    let transform: CGAffineTransform
}

extension CGAffineTransform: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let a = try container.decode(CGFloat.self, forKey: .a)
        let b = try container.decode(CGFloat.self, forKey: .b)
        let c = try container.decode(CGFloat.self, forKey: .c)
        let d = try container.decode(CGFloat.self, forKey: .d)
        let tx = try container.decode(CGFloat.self, forKey: .tx)
        let ty = try container.decode(CGFloat.self, forKey: .ty)
        self.init(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(a, forKey: .a)
        try container.encode(b, forKey: .b)
        try container.encode(c, forKey: .c)
        try container.encode(d, forKey: .d)
        try container.encode(tx, forKey: .tx)
        try container.encode(ty, forKey: .ty)
    }
    
    private enum CodingKeys: String, CodingKey {
        case a, b, c, d, tx, ty
    }
}