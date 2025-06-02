import SwiftUI

struct BlockShapeView: View {
    let block: Block
    let cellSize: CGFloat
    let isPreview: Bool
    let isValid: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<block.shape.cells.count, id: \.self) { idx in
                let cell = block.shape.cells[idx]
                Rectangle()
                    .fill(block.color.color)
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(cellSize * 0.2)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: cellSize * 0.2)
                            .stroke(isPreview ? (isValid ? Color.green : Color.red) : Color.clear, lineWidth: isPreview ? 3 : 0)
                    )
                    .position(x: CGFloat(cell.0) * cellSize + cellSize/2, y: CGFloat(cell.1) * cellSize + cellSize/2)
            }
        }
        .frame(width: shapeWidth, height: shapeHeight)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: block.id)
    }
    
    private var shapeWidth: CGFloat {
        let maxX = block.shape.cells.map { $0.0 }.max() ?? 0
        return CGFloat(maxX + 1) * cellSize
    }
    private var shapeHeight: CGFloat {
        let maxY = block.shape.cells.map { $0.1 }.max() ?? 0
        return CGFloat(maxY + 1) * cellSize
    }
} 