package falling_sands

import "core:fmt"
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

Particles :: enum {
	None,
	Sand,
	Rock,
	Water,
}

Particle :: struct {
	color:   rl.Color,
	type:    Particles,
	updated: bool, // Flag to prevent multiple updates per frame
}

// Constants
SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 600
FPS :: 120
CELL_SIZE :: 4
ROWS: int : int(SCREEN_HEIGHT / CELL_SIZE)
COLS: int : int(SCREEN_WIDTH / CELL_SIZE)
BRUSH_SIZE :: 3

// Colors
GREY :: rl.Color{29, 29, 29, 255}
LIGHT_GREY :: rl.Color{55, 55, 55, 255}
SAND_COLOR :: rl.Color{167, 137, 82, 255}
ROCK_COLOR :: rl.Color{115, 104, 101, 255}
WATER_COLOR :: rl.Color{43, 103, 179, 255}

// Variables
cells: [ROWS][COLS]Particle
p_type: [3]Particles
p_num: u8
m_pos: rl.Vector2
paused: bool
showFPS: bool

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Falling Sands Simulation")
	rl.SetTargetFPS(FPS)
	defer rl.CloseWindow()

	initGame()
	rl.HideCursor()

	for !rl.WindowShouldClose() {
		updateGame()
	}
}

// Initialize game state
initGame :: proc() {
	for &row in cells {
		for &cell in row {
			cell = Particle{LIGHT_GREY, .None, false}
		}
	}

	p_num = 0
	p_type = {.Sand, .Rock, .Water}
	paused = false
	showFPS = false
}

// Handle controls
controls :: proc() {
	m_pos = rl.GetMousePosition()
	row := int(m_pos.y / CELL_SIZE)
	col := int(m_pos.x / CELL_SIZE)

	if inBounds(row, col) {
		if rl.IsMouseButtonDown(.LEFT) {
			applyBrush(row, col, 'a', p_type[p_num])
		}
		if rl.IsMouseButtonPressed(.RIGHT) {
			applyBrush(row, col, 'e')
		}
	}

	if rl.IsKeyPressed(.R) {
		initGame()
	}

	if rl.IsKeyPressed(.T) {
		p_num = (p_num + 1) %% len(p_type)
	}

	if rl.IsKeyPressed(.SPACE) {
		paused = !paused
	}

	if rl.IsKeyPressed(.F) {
		showFPS = !showFPS
	}
}

// Update game
updateGame :: proc() {
	controls()
	if !paused {
		particleSimulation()
	}
	drawGame()
}

// Draw all elements
drawGame :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(GREY)

	drawGrid()
	drawBrush()

	if showFPS {
		rl.DrawFPS(10, 10)
	}
}

// Draw particles
drawGrid :: proc() {
	for row in 0 ..< ROWS {
		for col in 0 ..< COLS {
			particle := cells[row][col]

			if particle.type != .None {
				rl.DrawRectangle(
					i32(col * CELL_SIZE),
					i32(row * CELL_SIZE),
					CELL_SIZE,
					CELL_SIZE,
					particle.color,
				)
			}
		}
	}
}

// Draw brush preview
drawBrush :: proc() {
	col := int(m_pos.x / CELL_SIZE)
	row := int(m_pos.y / CELL_SIZE)

	brush_size := i32(BRUSH_SIZE * CELL_SIZE)
	color: rl.Color

	#partial switch p_type[p_num] {
	case .Sand:
		color = SAND_COLOR
	case .Rock:
		color = ROCK_COLOR
	case .Water:
		color = WATER_COLOR
	}

	rl.DrawRectangle(i32(col * CELL_SIZE), i32(row * CELL_SIZE), brush_size, brush_size, color)
}

// Utility functions
inBounds :: proc(row, col: int) -> bool {
	return (row >= 0 && row < ROWS) && (col >= 0 && col < COLS)
}

isEmptyCell :: proc(row, col: int) -> bool {
	return inBounds(row, col) && cells[row][col].type == .None
}

setParticleColor :: proc(particle: Particles) -> rl.Color {
	#partial switch particle {
	case .None:
		return LIGHT_GREY
	case .Sand:
		return randColor(37, 42, .5, .7, .6, .7)
	case .Rock:
		return randColor(8, 12, .1, .15, .3, .5)
	case .Water:
		return randColor(213, 214, .75, .76, .70, .71)
	}
	return LIGHT_GREY
}

addParticle :: proc(row, col: int, type: Particles) {
	if isEmptyCell(row, col) {
		if type == .Sand || type == .Water {
			if rand.float32() < 0.30 {
				cells[row][col] = Particle{setParticleColor(type), type, false}
			}
		} else {
			cells[row][col] = Particle{setParticleColor(type), type, false}
		}
	}
}

removeParticle :: proc(row, col: int) {
	if !isEmptyCell(row, col) {
		cells[row][col] = Particle{LIGHT_GREY, .None, false}
	}
}

applyBrush :: proc(row, col: int, type: rune, particle: Particles = .None) {
	for r in 0 ..< BRUSH_SIZE {
		for c in 0 ..< BRUSH_SIZE {
			c_row := row + r
			c_col := col + c

			if inBounds(c_row, c_col) {
				if type == 'e' {
					removeParticle(c_row, c_col)
				} else if type == 'a' {
					addParticle(c_row, c_col, particle)
				}
			}
		}
	}
}

randColor :: proc(h1, h2, s1, s2, v1, v2: f32) -> rl.Color {
	hue := rand.float32_uniform(h1, h2)
	saturation := rand.float32_uniform(s1, s2)
	value := rand.float32_uniform(v1, v2)
	return rl.ColorFromHSV(hue, saturation, value)
}


// Swap two particles
swapParticles :: proc(row1, col1, row2, col2: int) {
	temp := cells[row1][col1]
	cells[row1][col1] = cells[row2][col2]
	cells[row2][col2] = temp

	cells[row1][col1].updated = true
	cells[row2][col2].updated = true
}

// Update sand particle with desired logic

updateSand :: proc(row, col: int) {
	if !inBounds(row, col) || cells[row][col].type != .Sand {
		return
	}

	if cells[row][col].updated {
		return // Skip if already updated
	}

	// **Attempt to Move Down**
	if isEmptyCell(row + 1, col) {
		swapParticles(row, col, row + 1, col)
		return
	}

	// **Attempt Diagonal Movement into Empty Spaces Only**
	directions: [2]int = {-1, 1}
	rand.shuffle(directions[:])
	for dir in directions {
		new_col := col + dir
		if cells[row][new_col].type == .Rock do continue

		// **Move Diagonally if the space is empty**
		if isEmptyCell(row + 1, new_col) {
			swapParticles(row, col, row + 1, new_col)
			return
		}
	}

	// **Swap with Water Directly Below**
	if inBounds(row + 1, col) &&
	   cells[row + 1][col].type == .Water &&
	   !cells[row + 1][col].updated {
		swapParticles(row, col, row + 1, col)
		return
	}

	// **No Movement Possible**
	cells[row][col].updated = true
}

// Update water particle
updateWater :: proc(row, col: int) {
	if !inBounds(row, col) || cells[row][col].type != .Water {
		return
	}

	if cells[row][col].updated {
		return // Skip if already updated
	}

	directions := [2]int{-1, 1}
	rand.shuffle(directions[:])

	// **Attempt to Move Down**
	if isEmptyCell(row + 1, col) {
		swapParticles(row, col, row + 1, col)
		return
	}

	// **Attempt Diagonal Movement**
	for dir in directions {
		new_col := col + dir


		// **Move Diagonally if Possible**
		if isEmptyCell(row + 1, new_col) {
			if cells[row][new_col].type == .Rock do continue
			swapParticles(row, col, row + 1, new_col)
			return
		}

		// **Move Sideways if Possible**
		if isEmptyCell(row, new_col) {
			swapParticles(row, col, row, new_col)
			return
		}
	}

	// **No Movement Possible**
	cells[row][col].updated = true
}

// Update particle positions
updateParticle :: proc(row, col: int) {
	particle := &cells[row][col]
	if particle.type == .None || particle.updated {
		return // Skip empty or already updated particles
	}

	#partial switch particle.type {
	case .Sand:
		updateSand(row, col)
	case .Water:
		updateWater(row, col)
	case:
		particle.updated = true
	}
}

particleSimulation :: proc() {
	// **Reset update flags**
	for &row in cells {
		for &cell in row {
			cell.updated = false
		}
	}

	// **First Pass: Update Sand Particles from Top to Bottom**
	for row := ROWS - 1; row >= 0; row -= 1 {
		if row %% 2 == 0 {
			for col in 0 ..< COLS {
				if cells[row][col].type == .Sand {
					updateSand(row, col)
				}
			}
		} else {
			for col := COLS - 1; col >= 0; col -= 1 {
				if cells[row][col].type == .Sand {
					updateParticle(row, col)
				}
			}
		}
	}

	// **Second Pass: Update Water Particles from Bottom to Top**
	for row := ROWS - 1; row >= 0; row -= 1 {
		if row %% 2 == 0 {
			for col in 0 ..< COLS {
				if cells[row][col].type == .Water {
					updateWater(row, col)
				}
			}
		} else {
			for col := COLS - 1; col >= 0; col -= 1 {
				if cells[row][col].type == .Water {
					updateParticle(row, col)
				}
			}

		}
	}
}
