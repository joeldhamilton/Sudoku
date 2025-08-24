//
//  ContentView.swift
//  Sudoku
//
//  Created by Joel Hamilton on 8/24/25.
//

import SwiftUI

// MARK: - Entry Point
@main
struct SudokuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Model
struct Cell: Identifiable, Codable, Equatable {
    let row: Int
    let col: Int
    var value: Int? // 1...9
    var given: Bool
    var notes: Set<Int> = [] // pencil marks
    var isConflicted: Bool = false
    var isSelected: Bool = false
    var id: String { "\(row)-\(col)" }
}

struct Board: Codable, Equatable {
    static let size = 9
    var cells: [Cell] // 81 cells, row-major

    init(cells: [Cell]) {
        self.cells = cells
    }

    init(empty: Void = ()) {
        var tmp: [Cell] = []
        tmp.reserveCapacity(Board.size * Board.size)
        for r in 0..<Board.size {
            for c in 0..<Board.size {
                tmp.append(Cell(row: r, col: c, value: nil, given: false))
            }
        }
        self.cells = tmp
    }

    static func index(row: Int, col: Int) -> Int { row * size + col }

    subscript(_ row: Int, _ col: Int) -> Cell {
        get { cells[Board.index(row: row, col: col)] }
        set { cells[Board.index(row: row, col: col)] = newValue }
    }

    func rowValues(_ r: Int) -> Set<Int> {
        Set((0..<Board.size).compactMap { self[r, $0].value })
    }

    func colValues(_ c: Int) -> Set<Int> {
        Set((0..<Board.size).compactMap { self[$0, c].value })
    }

    func boxValues(row r: Int, col c: Int) -> Set<Int> {
        let br = (r / 3) * 3
        let bc = (c / 3) * 3
        var s: Set<Int> = []
        for i in 0..<3 {
            for j in 0..<3 {
                if let v = self[br + i, bc + j].value { s.insert(v) }
            }
        }
        return s
    }

    func candidates(row r: Int, col c: Int) -> Set<Int> {
        guard self[r, c].value == nil else { return [] }
        let used = rowValues(r).union(colValues(c)).union(boxValues(row: r, col: c))
        return Set(1...9).subtracting(used)
    }

    func isValidPlacement(_ v: Int, at r: Int, _ c: Int) -> Bool {
        !rowValues(r).contains(v) && !colValues(c).contains(v) && !boxValues(row: r, col: c).contains(v)
    }

    func isSolved() -> Bool {
        for r in 0..<9 { for c in 0..<9 { if self[r, c].value == nil { return false } } }
        // quick validity: each row/col/box must be 1..9
        let target = Set(1...9)
        for r in 0..<9 { if rowValues(r) != target { return false } }
        for c in 0..<9 { if colValues(c) != target { return false } }
        for br in stride(from: 0, to: 9, by: 3) {
            for bc in stride(from: 0, to: 9, by: 3) {
                if boxValues(row: br, col: bc) != target { return false }
            }
        }
        return true
    }
}

// MARK: - Solver (Backtracking with MRV)
struct SudokuSolver {
    // Solve given grid (0 for empty). Returns solved grid or nil. Optionally count up to two solutions.
    static func solve(grid: inout [[Int]], countSolutionsOnly: Bool = false, solutionsFound: inout Int, stopAt: Int = 1) -> Bool {
        // Find cell with minimum remaining values (MRV)
        var bestR = -1, bestC = -1
        var bestCandidates: [Int] = []
        var bestCount = 10

        for r in 0..<9 {
            for c in 0..<9 {
                if grid[r][c] == 0 {
                    let cand = candidates(in: grid, r, c)
                    let count = cand.count
                    if count == 0 { return false }
                    if count < bestCount {
                        bestCount = count
                        bestCandidates = cand
                        bestR = r; bestC = c
                        if count == 1 { break }
                    }
                }
            }
        }

        // If no empty cells => solved
        if bestR == -1 {
            solutionsFound += 1
            return true
        }

        for v in bestCandidates.shuffled() {
            if isValid(grid, bestR, bestC, v) {
                grid[bestR][bestC] = v
                if solve(grid: &grid, countSolutionsOnly: countSolutionsOnly, solutionsFound: &solutionsFound, stopAt: stopAt) {
                    if countSolutionsOnly {
                        if solutionsFound >= stopAt { return true }
                    } else {
                        return true
                    }
                }
                grid[bestR][bestC] = 0
            }
        }
        return false
    }

    static func isValid(_ g: [[Int]], _ r: Int, _ c: Int, _ v: Int) -> Bool {
        for i in 0..<9 { if g[r][i] == v || g[i][c] == v { return false } }
        let br = (r/3)*3, bc = (c/3)*3
        for i in 0..<3 { for j in 0..<3 { if g[br+i][bc+j] == v { return false } } }
        return true
    }

    static func candidates(in g: [[Int]], _ r: Int, _ c: Int) -> [Int] {
        var used = Set<Int>()
        for i in 0..<9 { if g[r][i] != 0 { used.insert(g[r][i]) } }
        for i in 0..<9 { if g[i][c] != 0 { used.insert(g[i][c]) } }
        let br = (r/3)*3, bc = (c/3)*3
        for i in 0..<3 { for j in 0..<3 { let v = g[br+i][bc+j]; if v != 0 { used.insert(v) } } }
        return Array(Set(1...9).subtracting(used)).sorted()
    }

    static func fromBoard(_ board: Board) -> [[Int]] {
        var g = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        for r in 0..<9 {
            for c in 0..<9 {
                g[r][c] = board[r, c].value ?? 0
            }
        }
        return g
    }

    static func toBoard(_ grid: [[Int]], givensMask: [[Bool]]? = nil) -> Board {
        var cells: [Cell] = []
        for r in 0..<9 {
            for c in 0..<9 {
                let v = grid[r][c] == 0 ? nil : grid[r][c]
                let given = givensMask?[r][c] ?? (v != nil)
                cells.append(Cell(row: r, col: c, value: v, given: given))
            }
        }
        return Board(cells: cells)
    }
}

// MARK: - Generator (fill + carve with uniqueness check)
struct SudokuGenerator {
    static func generate(difficulty: Difficulty) -> (puzzle: Board, solution: Board) {
        // Step 1: generate a full valid grid
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        _ = fill(&grid)

        // Keep a copy as solution
        let solvedBoard = SudokuSolver.toBoard(grid)

        // Step 2: carve cells while maintaining unique solution
        var puzzle = grid
        var positions: [(Int, Int)] = []
        for r in 0..<9 { for c in 0..<9 { positions.append((r,c)) } }
        positions.shuffle()

        let targetRemovals: Int
        switch difficulty {
        case .easy: targetRemovals = 40 // ~41 clues -> easier
        case .medium: targetRemovals = 50
        case .hard: targetRemovals = 56
        }

        var removed = 0
        for (r, c) in positions {
            if removed >= targetRemovals { break }
            let backup = puzzle[r][c]
            puzzle[r][c] = 0
            // Check uniqueness (stop at 2 solutions)
            var testGrid = puzzle
            var count = 0
            let _ = SudokuSolver.solve(grid: &testGrid, countSolutionsOnly: true, solutionsFound: &count, stopAt: 2)
            if count == 1 { // unique, keep removed
                removed += 1
            } else {
                puzzle[r][c] = backup // revert
            }
        }

        // Create givens mask from puzzle (non-zero)
        var mask = Array(repeating: Array(repeating: false, count: 9), count: 9)
        for r in 0..<9 { for c in 0..<9 { mask[r][c] = puzzle[r][c] != 0 } }

        return (SudokuSolver.toBoard(puzzle, givensMask: mask), solvedBoard)
    }

    private static func fill(_ grid: inout [[Int]]) -> Bool {
        // Similar to solver, but try random numbers 1..9
        for r in 0..<9 {
            for c in 0..<9 {
                if grid[r][c] == 0 {
                    for v in (1...9).shuffled() {
                        if SudokuSolver.isValid(grid, r, c, v) {
                            grid[r][c] = v
                            if fill(&grid) { return true }
                            grid[r][c] = 0
                        }
                    }
                    return false
                }
            }
        }
        return true
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy, medium, hard
        var id: String { rawValue }
    }
}

// MARK: - View Model
@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var board: Board = Board(empty: ())
    @Published private(set) var solution: Board = Board(empty: ())
    @Published var selected: (row: Int, col: Int)? = nil
    @Published var pencilMode: Bool = false
    @Published var highlightPeers: Bool = true
    @Published var mistakes: Int = 0
    @Published var elapsed: TimeInterval = 0
    @Published var difficulty: SudokuGenerator.Difficulty = .easy

    private var timer: Timer? = nil
    private var startDate: Date? = nil

    // Undo/redo
    private var undoStack: [Board] = []
    private var redoStack: [Board] = []

    init() {
        newGame()
    }

    func newGame() {
        let result = SudokuGenerator.generate(difficulty: difficulty)
        withAnimation {
            self.board = result.puzzle
            self.solution = result.solution
            self.selected = nil
            self.mistakes = 0
            self.elapsed = 0
            self.undoStack = []
            self.redoStack = []
        }
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startDate else { return }
            self.elapsed = Date().timeIntervalSince(start)
        }
    }

    func stopTimer() { timer?.invalidate(); timer = nil }

    func selectCell(row: Int, col: Int) {
        selected = (row, col)
        updateSelectionHighlights()
    }

    func enterDigit(_ d: Int) {
        guard let sel = selected else { return }
        var cell = board[sel.row, sel.col]
        guard !cell.given else { return }

        pushUndo()
        if pencilMode {
            if cell.value != nil { cell.value = nil }
            if cell.notes.contains(d) { cell.notes.remove(d) } else { cell.notes.insert(d) }
            board[sel.row, sel.col] = cell
        } else {
            cell.notes = []
            if cell.value == d {
                cell.value = nil
            } else {
                cell.value = d
            }
            board[sel.row, sel.col] = cell
            validateConflictsAround(row: sel.row, col: sel.col)
            if board.isSolved() { stopTimer() }
        }
        updateSelectionHighlights()
    }

    func erase() {
        guard let sel = selected else { return }
        var cell = board[sel.row, sel.col]
        guard !cell.given else { return }
        pushUndo()
        cell.value = nil
        cell.notes = []
        board[sel.row, sel.col] = cell
        validateConflictsAround(row: sel.row, col: sel.col)
        updateSelectionHighlights()
    }

    func hint() {
        // Fill a single-candidate if exists; else reveal the solution for selected cell
        // (You may expand with smarter strategies.)
        // Try singles
        for r in 0..<9 {
            for c in 0..<9 {
                if board[r, c].value == nil {
                    let cand = board.candidates(row: r, col: c)
                    if cand.count == 1, let v = cand.first {
                        pushUndo()
                        var cell = board[r, c]
                        cell.value = v
                        cell.notes = []
                        board[r, c] = cell
                        validateConflictsAround(row: r, col: c)
                        updateSelectionHighlights()
                        return
                    }
                }
            }
        }
        // Otherwise use solution for selected
        if let sel = selected, board[sel.row, sel.col].value == nil, let sol = solution[sel.row, sel.col].value {
            pushUndo()
            var cell = board[sel.row, sel.col]
            cell.value = sol
            cell.notes = []
            board[sel.row, sel.col] = cell
            validateConflictsAround(row: sel.row, col: sel.col)
            updateSelectionHighlights()
        }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(board)
        board = last
        updateSelectionHighlights()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(board)
        board = next
        updateSelectionHighlights()
    }

    private func pushUndo() { undoStack.append(board); redoStack.removeAll() }

    private func updateSelectionHighlights() {
        guard let sel = selected else {
            for idx in 0..<board.cells.count { board.cells[idx].isSelected = false; board.cells[idx].isConflicted = false }
            return
        }
        let rSel = sel.row, cSel = sel.col
        let valSel = board[rSel, cSel].value
        for r in 0..<9 {
            for c in 0..<9 {
                var cell = board[r, c]
                cell.isSelected = (r == rSel && c == cSel) || (highlightPeers && (r == rSel || c == cSel || (r/3 == rSel/3 && c/3 == cSel/3)))
                // same number highlight (non-given helpful UX)
                if let v = valSel, board[r, c].value == v { cell.isSelected = true }
                board[r, c] = cell
            }
        }
        validateConflictsEntireBoard()
    }

    private func validateConflictsEntireBoard() {
        for r in 0..<9 { for c in 0..<9 { board[r, c].isConflicted = false } }
        for r in 0..<9 {
            var seen: [Int: [(Int,Int)]] = [:]
            for c in 0..<9 { if let v = board[r, c].value { seen[v, default: []].append((r,c)) } }
            for (_, coords) in seen where coords.count > 1 { for (rr,cc) in coords { board[rr,cc].isConflicted = true } }
        }
        for c in 0..<9 {
            var seen: [Int: [(Int,Int)]] = [:]
            for r in 0..<9 { if let v = board[r, c].value { seen[v, default: []].append((r,c)) } }
            for (_, coords) in seen where coords.count > 1 { for (rr,cc) in coords { board[rr,cc].isConflicted = true } }
        }
        for br in stride(from: 0, to: 9, by: 3) {
            for bc in stride(from: 0, to: 9, by: 3) {
                var seen: [Int: [(Int,Int)]] = [:]
                for i in 0..<3 { for j in 0..<3 { let r = br+i, c = bc+j; if let v = board[r,c].value { seen[v, default: []].append((r,c)) } } }
                for (_, coords) in seen where coords.count > 1 { for (rr,cc) in coords { board[rr,cc].isConflicted = true } }
            }
        }
    }

    private func validateConflictsAround(row: Int, col: Int) {
        validateConflictsEntireBoard()
        if board[row, col].isConflicted { mistakes += 1 }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var vm = GameViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header
                SudokuGridView(board: vm.board, selected: vm.selected, tap: vm.selectCell)
                    .padding(.horizontal)
                NumberPad(
                    pencilMode: vm.pencilMode,
                    onDigit: vm.enterDigit,
                    onErase: vm.erase,
                    onHint: vm.hint,
                    onTogglePencil: { vm.pencilMode.toggle() },
                    onUndo: vm.undo,
                    onRedo: vm.redo
                )
                controls
            }
            .navigationTitle("Sudoku")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("New Game") {
                        Picker("Difficulty", selection: $vm.difficulty) {
                            ForEach(SudokuGenerator.Difficulty.allCases) { d in
                                Text(d.rawValue.capitalized).tag(d)
                            }
                        }
                        .pickerStyle(.inline)
                        Button("Start") { vm.newGame() }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Label("\(formatTime(vm.elapsed))", systemImage: "timer")
            Spacer()
            Label("Mistakes: \(vm.mistakes)", systemImage: "exclamationmark.triangle")
        }
        .font(.headline)
        .padding(.horizontal)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $vm.pencilMode) { Text("Pencil") }.toggleStyle(.button).labelStyle(.titleOnly)
            Spacer()
            Button("Undo", action: vm.undo)
            Button("Redo", action: vm.redo)
            Button("Hint", action: vm.hint)
            Button("New") { vm.newGame() }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        let m = s / 60
        let ss = s % 60
        return String(format: "%02d:%02d", m, ss)
    }
}

struct SudokuGridView: View {
    let board: Board
    let selected: (row: Int, col: Int)?
    var tap: (Int, Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.width) // square
            let cellSize = size / 9

            ZStack {
                // Outer border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(lineWidth: 2)
                    .foregroundStyle(.secondary)

                // 9x9 cells
                ForEach(0..<9, id: \.self) { r in
                    ForEach(0..<9, id: \.self) { c in
                        let cell = board[r, c]
                        CellView(cell: cell)
                            .frame(width: cellSize, height: cellSize)
                            .position(x: cellSize * (CGFloat(c) + 0.5), y: cellSize * (CGFloat(r) + 0.5))
                            .contentShape(Rectangle())
                            .onTapGesture { tap(r, c) }
                    }
                }

                // Bold 3x3 separators
                Path { p in
                    for i in 1..<3 {
                        let pos = CGFloat(i) * (size / 3)
                        p.move(to: CGPoint(x: pos, y: 0))
                        p.addLine(to: CGPoint(x: pos, y: size))
                        p.move(to: CGPoint(x: 0, y: pos))
                        p.addLine(to: CGPoint(x: size, y: pos))
                    }
                }
                .stroke(style: StrokeStyle(lineWidth: 3))
                .foregroundStyle(.primary)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct CellView: View {
    let cell: Cell

    var body: some View {
        ZStack {
            Rectangle()
                .fill(cellBackground)
                .overlay(
                    Rectangle()
                        .strokeBorder(cell.isConflicted ? Color.red : Color.secondary.opacity(0.4), lineWidth: 0.5)
                )

            if let v = cell.value {
                Text("\(v)")
                    .font(cell.given ? .title2.weight(.bold) : .title2)
                    .foregroundStyle(cell.given ? .primary : .blue)
            } else if !cell.notes.isEmpty {
                notesGrid
            }
        }
    }

    private var cellBackground: Color {
        if cell.isSelected { return Color.yellow.opacity(0.25) }
        return Color.clear
    }

    private var notesGrid: some View {
        GeometryReader { geo in
            let side = geo.size.width / 3
            ZStack {
                ForEach(1...9, id: \.self) { n in
                    if cell.notes.contains(n) {
                        let idx = n - 1
                        let r = idx / 3
                        let c = idx % 3
                        Text("\(n)")
                            .font(.system(size: side * 0.45))
                            .foregroundStyle(.secondary)
                            .position(x: side * (CGFloat(c) + 0.5), y: side * (CGFloat(r) + 0.55))
                    }
                }
            }
        }
    }
}

struct NumberPad: View {
    var pencilMode: Bool
    var onDigit: (Int) -> Void
    var onErase: () -> Void
    var onHint: () -> Void
    var onTogglePencil: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...9, id: \.self) { n in
                    Button(action: { onDigit(n) }) { Text("\(n)").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                }
            }
            HStack(spacing: 8) {
                Button(action: onErase) { Label("Erase", systemImage: "eraser") }
                Button(action: onHint) { Label("Hint", systemImage: "lightbulb") }
                Button(action: onTogglePencil) { Label(pencilMode ? "Pencil On" : "Pencil Off", systemImage: "pencil") }
                Button(action: onUndo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                Button(action: onRedo) { Label("Redo", systemImage: "arrow.uturn.forward") }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }
}

// MARK: - Board subscript mutability helper
extension Board {
    subscript(_ row: Int, _ col: Int) -> Cell {
        get { cells[Board.index(row: row, col: col)] }
        set { cells[Board.index(row: row, col: col)] = newValue }
    }
}

// MARK: - Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.light)
        ContentView()
            .preferredColorScheme(.dark)
    }
}
