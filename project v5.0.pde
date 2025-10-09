int cols = 8;
int rows = 8;
Tile[][] tiles = new Tile[cols][rows];
Tile activeTile = null; // currently selected tile

float gridX, gridY; // top-left corner of grid
float tileSize = 70; // size of each tile
float gap = 2; // spacing between tiles

// Piece images
PImage hamKnightImg, hamQueenImg, hamBishopImg, hamPawnImg, hamRookImg, hamKingImg;
PImage tobisKnightImg, tobisQueenImg, tobisBishopImg, tobisPawnImg, tobisRookImg, tobisKingImg;

// Pieces array
Piece[][] pieces = new Piece[cols][rows];

Piece selectedPiece = null;
String currentTurn = "ham";
Piece previewedEnemy = null;

ChessEngine engine;
int searchDepth = 4;

boolean aiThinking = false;
AIMove aiResult = null;
int boardW, boardH;  // <— add these globals

void settings() {
  boardW = int(cols * (tileSize + gap) - gap) + 100;
  boardH = int(rows * (tileSize + gap) - gap) + 100;
  size(boardW, boardH);  // must be here if using variables
}

void setup() {
  gridX = (width  - cols * (tileSize + gap) + gap) / 2;
  gridY = (height - rows * (tileSize + gap) + gap) / 2;


  // Load Ham pieces
  hamKnightImg = loadImage("HamKnight.png");
  hamQueenImg  = loadImage("HamQueen.png");
  hamBishopImg = loadImage("HamBishop.png");
  hamPawnImg = loadImage("HamPawn.png");
  hamRookImg = loadImage("HamRook.png");
  hamKingImg = loadImage("KingHam.png");

  // Load Tobis pieces
  tobisKnightImg = loadImage("TobisKnight.png");
  tobisQueenImg = loadImage("TobisQueen.png");
  tobisBishopImg = loadImage("TobisBishop.png");
  tobisPawnImg = loadImage("TobisPawn.png");
  tobisRookImg = loadImage("TobisRook.png");
  tobisKingImg = loadImage("KingTobis.png");

  gridX = (width - cols * (tileSize + gap) + gap) / 2;
  gridY = (height - rows * (tileSize + gap) + gap) / 2;
  
  // Create board tiles
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      color c;
      if ((i + j) % 2 == 0) {
        c = color(169, 169, 169); // light tile
      } else {
        c = color(119, 136, 153); // dark tile
      }
      float x = gridX + i * (tileSize + gap);
      float y = gridY + j * (tileSize + gap);
      tiles[i][j] = new Tile(x, y, tileSize, tileSize, c, i, j);
    }
  }

// --- Place Ham pieces (bottom, row 7) ---
pieces[0][7] = new Piece(hamRookImg,   0, 7, "rook",   "ham");
pieces[1][7] = new Piece(hamKnightImg, 1, 7, "knight", "ham");
pieces[2][7] = new Piece(hamBishopImg, 2, 7, "bishop", "ham");
pieces[3][7] = new Piece(hamQueenImg,  3, 7, "queen",  "ham");
pieces[4][7] = new Piece(hamKingImg,   4, 7, "king",   "ham");
pieces[5][7] = new Piece(hamBishopImg, 5, 7, "bishop", "ham");
pieces[6][7] = new Piece(hamKnightImg, 6, 7, "knight", "ham");
pieces[7][7] = new Piece(hamRookImg,   7, 7, "rook",   "ham");

// Ham pawns (row 6)
for (int i = 0; i < cols; i++) {
  pieces[i][6] = new Piece(hamPawnImg, i, 6, "pawn", "ham");
}

// --- Place Tobis pieces (top, row 0) ---
pieces[0][0] = new Piece(tobisRookImg,   0, 0, "rook",   "tobis");
pieces[1][0] = new Piece(tobisKnightImg, 1, 0, "knight", "tobis");
pieces[2][0] = new Piece(tobisBishopImg, 2, 0, "bishop", "tobis");
pieces[3][0] = new Piece(tobisQueenImg,  3, 0, "queen",  "tobis");
pieces[4][0] = new Piece(tobisKingImg,   4, 0, "king",   "tobis");
pieces[5][0] = new Piece(tobisBishopImg, 5, 0, "bishop", "tobis");
pieces[6][0] = new Piece(tobisKnightImg, 6, 0, "knight", "tobis");
pieces[7][0] = new Piece(tobisRookImg,   7, 0, "rook",   "tobis");

// Tobis pawns (row 1)
for (int i = 0; i < cols; i++) {
  pieces[i][1] = new Piece(tobisPawnImg, i, 1, "pawn", "tobis");
}
  engine = new ChessEngine(pieces, cols, rows, currentTurn);
}

void draw() {
  background(255);

  // black background behind board
  float boardW = cols * (tileSize + gap) - gap;
  float boardH = rows * (tileSize + gap) - gap;
  fill(0);
  noStroke();
  rect(gridX - gap, gridY - gap, boardW + 2*gap, boardH + 2*gap);

  //draw tiles
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      tiles[i][j].update();
      tiles[i][j].display();
    }
  }

  //draw pieces on top of tiles
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (pieces[i][j] != null) {
        pieces[i][j].display();
      }
    }
  }

  //if AI finished thinking, apply the move
  if (!aiThinking && aiResult != null) {
    engine.selected = aiResult.piece;
    engine.moveSelectedTo(aiResult.c, aiResult.r);
    engine.clearSelection();

    currentTurn = "ham";
    engine.turn = currentTurn;

    selectedPiece = null;
    previewedEnemy = null;

    aiResult = null;
    deselectAll();
  }

  // --- optional "thinking" indicator ---
  if (aiThinking) {
    fill(0);
    textAlign(CENTER);
    text("Tobis is thinking...", width/2, 20);
  }
}



void mousePressed() {
  int clickedCol = -1, clickedRow = -1;
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (tiles[i][j].isMouseOver()) {
        clickedCol = i;
        clickedRow = j;
      }
    }
  }
  if (clickedCol == -1 || clickedRow == -1) { 
    deselectAll(); 
    return; 
  }

  Tile clickedTile = tiles[clickedCol][clickedRow];
  Piece p = pieces[clickedCol][clickedRow];
  boolean isHighlighted = tiles[clickedCol][clickedRow].highlighted;

  // --- NO PIECE CURRENTLY SELECTED ---
  if (selectedPiece == null) {
    if (p != null) {
      if (p.side.equals(currentTurn)) {
        // Select your own piece (clear old highlights)
        deselectAll();
        selectPiece(p);
      } else {
        // ENEMY: toggle/preview without clearing first
        previewEnemy(p);
      }
    } else {
      // Clicked an empty tile
      if (isHighlighted && previewedEnemy != null) {
        // Keep preview highlights when clicking a highlighted EMPTY tile
        return;
      }
      // Otherwise clear as normal
      deselectAll();
      activeTile = clickedTile;
      activeTile.goUp();
    }
    return;
  }

  // --- A PIECE IS SELECTED HAMSIDE ---
  if (selectedPiece.col == clickedCol && selectedPiece.row == clickedRow) {
    // clicking same piece deselects
    deselectAll();
    return;
  }

  if (isHighlighted) {
    // Legal move (empty or capture) according to your UI highlights → perform move (HAM)
    pieces[selectedPiece.col][selectedPiece.row] = null;
    selectedPiece.col = clickedCol;
    selectedPiece.row = clickedRow;

    // Pawn promotion (your existing logic)
    if (selectedPiece.type.equals("pawn")) {
      if ((selectedPiece.side.equals("ham") && selectedPiece.row == 0) || 
          (selectedPiece.side.equals("tobis") && selectedPiece.row == rows - 1)) {
        selectedPiece.type = "queen";
        selectedPiece.img = selectedPiece.side.equals("ham") ? hamQueenImg : tobisQueenImg;
        selectedPiece.scaleFactor = 2;
      }
    }

    pieces[clickedCol][clickedRow] = selectedPiece;

    // switch to Tobis turn
    currentTurn = "tobis";
    if (engine != null) engine.turn = currentTurn; // keep engine in sync

    // clear UI and run Tobis AI move immediately
    deselectAll();
    runTobisAIMove();   // <<< engine plays here

    return;
  }

  //clicked elsewhere with a piece selected
  deselectAll();
  if (p != null && p.side.equals(currentTurn)) {
    selectPiece(p);
  } else if (p != null) {
    previewEnemy(p);
  } else {
    activeTile = clickedTile;
    activeTile.goUp();
  }
}

void selectPiece(Piece p) {
  deselectAll();
  selectedPiece = p;
  highlightMoves(p);
  tiles[p.col][p.row].goUpHighlight();

  if (p.type.equals("knight")) {
    int[][] moves = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        if (pieces[nc][nr] == null || !pieces[nc][nr].side.equals(p.side)) {
          tiles[nc][nr].goUpHighlight();
        }
      }
    }
  } else if (p.type.equals("bishop") || p.type.equals("queen")) {
    for (int d = -1; d <= 1; d += 2) {
      for (int e = -1; e <= 1; e += 2) {
        for (int step = 1; step < 10; step++) {
          int nc = p.col + step*d;
          int nr = p.row + step*e;
          if (!inBounds(nc,nr)) break;
          if (pieces[nc][nr] == null) {
            tiles[nc][nr].goUpHighlight();
          } else {
            if (!pieces[nc][nr].side.equals(p.side)) tiles[nc][nr].goUpHighlight();
            break;
          }
        }
      }
    }
  }
  
  if (p.type.equals("king")) {
    int[][] moves = {{1,1},{1,0},{1,-1},{-1,-1},{-1,0},{-1,1},{0,1},{1,1},{0,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        if (pieces[nc][nr] == null || !pieces[nc][nr].side.equals(p.side)) {
          tiles[nc][nr].goUpHighlight();
        }
      }
    }
  }

  if (p.type.equals("queen") || p.type.equals("rook")) {
    for (int i = p.col + 1; i < cols; i++) {
      if (pieces[i][p.row] == null) {
        tiles[i][p.row].goUpHighlight();
      } else {
        if (!pieces[i][p.row].side.equals(p.side)) tiles[i][p.row].goUpHighlight();
        break;
      }
    }
    for (int i = p.col - 1; i >= 0; i--) {
      if (pieces[i][p.row] == null) {
        tiles[i][p.row].goUpHighlight();
      } else {
        if (!pieces[i][p.row].side.equals(p.side)) tiles[i][p.row].goUpHighlight();
        break;
      }
    }
    for (int j = p.row + 1; j < rows; j++) {
      if (pieces[p.col][j] == null) {
        tiles[p.col][j].goUpHighlight();
      } else {
        if (!pieces[p.col][j].side.equals(p.side)) tiles[p.col][j].goUpHighlight();
        break;
      }
    }
    for (int j = p.row - 1; j >= 0; j--) {
      if (pieces[p.col][j] == null) {
        tiles[p.col][j].goUpHighlight();
      } else {
        if (!pieces[p.col][j].side.equals(p.side)) tiles[p.col][j].goUpHighlight();
        break;
      }
    }
  }

  if (p.type.equals("pawn")) {
  int dir = p.side.equals("ham") ? -1 : 1;
  int startRow = p.side.equals("ham") ? rows - 2 : 1;

  // One step forward
  int nc = p.col;
  int nr = p.row + dir;
  if (inBounds(nc,nr) && pieces[nc][nr] == null) {
    tiles[nc][nr].goUpHighlight();

    // Two steps forward (only from starting row, and only if clear)
    int nr2 = p.row + 2*dir;
    if (p.row == startRow && inBounds(nc,nr2) && pieces[nc][nr2] == null) {
      tiles[nc][nr2].goUpHighlight();
    }
  }

  // Captures diagonally
  for (int dc = -1; dc <= 1; dc += 2) {
    nc = p.col + dc;
    nr = p.row + dir;
    if (inBounds(nc, nr) && pieces[nc][nr] != null && !pieces[nc][nr].side.equals(p.side)) {
      tiles[nc][nr].goUpHighlight();
    }
  }
}

}

void deselectAll() {
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      tiles[i][j].goDown(); // reset all tiles
    }
  }

  selectedPiece = null;
  previewedEnemy = null;

  if (activeTile != null) {
    activeTile.goDown();
    activeTile = null;
  }
}


void highlightMoves(Piece p) {
  tiles[p.col][p.row].goUpHighlight();

  if (p.type.equals("knight")) {
    int[][] moves = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        if (pieces[nc][nr] == null || !pieces[nc][nr].side.equals(p.side)) {
          tiles[nc][nr].goUpHighlight();
        }
      }
    }
  }

  else if (p.type.equals("bishop") || p.type.equals("queen")) {
    for (int d = -1; d <= 1; d += 2) {
      for (int e = -1; e <= 1; e += 2) {
        for (int step = 1; step < 10; step++) {
          int nc = p.col + step*d;
          int nr = p.row + step*e;
          if (!inBounds(nc,nr)) break;
          if (pieces[nc][nr] == null) {
            tiles[nc][nr].goUpHighlight();
          } else {
            if (!pieces[nc][nr].side.equals(p.side)) tiles[nc][nr].goUpHighlight();
            break;
          }
        }
      }
    }
  }

  if (p.type.equals("queen") || p.type.equals("rook")) {
    for (int i = p.col + 1; i < cols; i++) {
      if (pieces[i][p.row] == null) tiles[i][p.row].goUpHighlight();
      else { if (!pieces[i][p.row].side.equals(p.side)) tiles[i][p.row].goUpHighlight(); break; }
    }
    for (int i = p.col - 1; i >= 0; i--) {
      if (pieces[i][p.row] == null) tiles[i][p.row].goUpHighlight();
      else { if (!pieces[i][p.row].side.equals(p.side)) tiles[i][p.row].goUpHighlight(); break; }
    }
    for (int j = p.row + 1; j < rows; j++) {
      if (pieces[p.col][j] == null) tiles[p.col][j].goUpHighlight();
      else { if (!pieces[p.col][j].side.equals(p.side)) tiles[p.col][j].goUpHighlight(); break; }
    }
    for (int j = p.row - 1; j >= 0; j--) {
      if (pieces[p.col][j] == null) tiles[p.col][j].goUpHighlight();
      else { if (!pieces[p.col][j].side.equals(p.side)) tiles[p.col][j].goUpHighlight(); break; }
    }
  }

  if (p.type.equals("king")) {
    int[][] moves = {{1,1},{1,0},{1,-1},{-1,-1},{-1,0},{-1,1},{0,1},{0,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        if (pieces[nc][nr] == null || !pieces[nc][nr].side.equals(p.side)) {
          tiles[nc][nr].goUpHighlight();
        }
      }
    }
  }

  if (p.type.equals("pawn")) {
    int dir = p.side.equals("ham") ? -1 : 1;
    int startRow = p.side.equals("ham") ? rows - 2 : 1;

    // one step forward
    int nc = p.col;
    int nr = p.row + dir;
    if (inBounds(nc,nr) && pieces[nc][nr] == null) {
      tiles[nc][nr].goUpHighlight();
      // two steps forward
      int nr2 = p.row + 2*dir;
      if (p.row == startRow && inBounds(nc,nr2) && pieces[nc][nr2] == null) {
        tiles[nc][nr2].goUpHighlight();
      }
    }

    // diagonal captures
    for (int dc = -1; dc <= 1; dc += 2) {
      nc = p.col + dc;
      nr = p.row + dir;
      if (inBounds(nc,nr) && pieces[nc][nr] != null && !pieces[nc][nr].side.equals(p.side)) {
        tiles[nc][nr].goUpHighlight();
      }
    }
  }
}

void previewEnemy(Piece p) {
  if (p == null) return;

  // Toggle: if same enemy clicked again → clear
  if (previewedEnemy == p) {
    deselectAll();
    return;
  }

  deselectAll(); // clear old highlights first
  previewedEnemy = p;
  lightHighlightMoves(p);
}


void lightUpOnly(Tile t) {
  // Light the tile but not hover it
  t.highlighted = true;
}


void lightHighlightMoves(Piece p) {
  lightUpOnly(tiles[p.col][p.row]);

  if (p.type.equals("knight")) {
    int[][] moves = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        if (pieces[nc][nr] == null || !pieces[nc][nr].side.equals(p.side)) {
          lightUpOnly(tiles[nc][nr]);
        }
      }
    }
  }

  else if (p.type.equals("bishop") || p.type.equals("queen")) {
    for (int d = -1; d <= 1; d += 2) {
      for (int e = -1; e <= 1; e += 2) {
        for (int step = 1; step < 10; step++) {
          int nc = p.col + step*d;
          int nr = p.row + step*e;
          if (!inBounds(nc,nr)) break;
          if (pieces[nc][nr] == null) {
            lightUpOnly(tiles[nc][nr]);
          } else {
            if (!pieces[nc][nr].side.equals(p.side)) lightUpOnly(tiles[nc][nr]);
            break;
          }
        }
      }
    }
  }

  if (p.type.equals("queen") || p.type.equals("rook")) {
    for (int i = p.col + 1; i < cols; i++) {
      if (pieces[i][p.row] == null) lightUpOnly(tiles[i][p.row]);
      else { if (!pieces[i][p.row].side.equals(p.side)) lightUpOnly(tiles[i][p.row]); break; }
    }
    for (int i = p.col - 1; i >= 0; i--) {
      if (pieces[i][p.row] == null) lightUpOnly(tiles[i][p.row]);
      else { if (!pieces[i][p.row].side.equals(p.side)) lightUpOnly(tiles[i][p.row]); break; }
    }
    for (int j = p.row + 1; j < rows; j++) {
      if (pieces[p.col][j] == null) lightUpOnly(tiles[p.col][j]);
      else { if (!pieces[p.col][j].side.equals(p.side)) lightUpOnly(tiles[p.col][j]); break; }
    }
    for (int j = p.row - 1; j >= 0; j--) {
      if (pieces[p.col][j] == null) lightUpOnly(tiles[p.col][j]);
      else { if (!pieces[p.col][j].side.equals(p.side)) lightUpOnly(tiles[p.col][j]); break; }
    }
  }

  if (p.type.equals("king")) {
    int[][] moves = {{1,1},{1,0},{1,-1},{-1,-1},{-1,0},{-1,1},{0,1},{0,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        if (pieces[nc][nr] == null || !pieces[nc][nr].side.equals(p.side)) {
          lightUpOnly(tiles[nc][nr]);
        }
      }
    }
  }

  if (p.type.equals("pawn")) {
    int dir = p.side.equals("ham") ? -1 : 1;
    int startRow = p.side.equals("ham") ? rows - 2 : 1;

    int nc = p.col;
    int nr = p.row + dir;
    if (inBounds(nc,nr) && pieces[nc][nr] == null) {
      lightUpOnly(tiles[nc][nr]);
      int nr2 = p.row + 2*dir;
      if (p.row == startRow && inBounds(nc,nr2) && pieces[nc][nr2] == null) {
        lightUpOnly(tiles[nc][nr2]);
      }
    }

    for (int dc = -1; dc <= 1; dc += 2) {
      nc = p.col + dc;
      nr = p.row + dir;
      if (inBounds(nc,nr) && pieces[nc][nr] != null && !pieces[nc][nr].side.equals(p.side)) {
        lightUpOnly(tiles[nc][nr]);
      }
    }
  }
}



boolean inBounds(int c, int r) {
  return c >= 0 && c < cols && r >= 0 && r < rows;
}

// Tile class
class Tile {
  float x, y, w, h;
  color baseColor;
  color currentColor;
  float offset = 0;
  float targetOffset = 0;
  boolean highlighted = false;
  float highlightAmt = 0;
  int col, row;
  
  Tile(float x, float y, float w, float h, color c, int col, int row) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.baseColor = c;
    this.currentColor = c;
    this.col = col;
    this.row = row;
  }
  
  void update() {
    // faster snap for lift
    offset += (targetOffset - offset) * 0.3;
    // faster highlight fade
    float targetHighlight = highlighted ? 0.6 : 0;
    highlightAmt += (targetHighlight - highlightAmt) * 0.4;
    currentColor = lerpColor(baseColor, color(255), highlightAmt);
  }
  
  void display() {
    pushMatrix();
    translate(-offset, -offset);
    noStroke();
    fill(currentColor);
    rect(x, y, w, h);
    popMatrix();
  }
  
  void goUpHighlight() {
    targetOffset = w * 0.1;
    highlighted = true;
  }
  
  void goUp() {
    targetOffset = w * 0.1;
    highlighted = false;
  }
  
  void goDown() {
    targetOffset = 0;
    highlighted = false;
  }
  
  void lightUpOnly(Tile t) {
  t.highlighted = true;
  // do NOT set targetOffset, so tile stays flat
  }
  
  boolean isMouseOver() {
    return mouseX > x - offset && mouseX < x + w - offset &&
           mouseY > y - offset && mouseY < y + h - offset;
  }
}


// Piece class
class Piece {
  PImage img;
  int col, row;
  float x, y;
  String type;
  String side;
  float scaleFactor; // auto-set based on type
  
  Piece(PImage img, int col, int row, String type, String side) {
    this.img = img;
    this.col = col;
    this.row = row;
    this.type = type;
    this.side = side;
    this.x = gridX + col * (tileSize + gap);
    this.y = gridY + row * (tileSize + gap);
    
    // set scale automatically per type
    if (type.equals("pawn")&&side.equals("tobis")) scaleFactor = 1;
    if (type.equals("pawn")&&side.equals("ham")) scaleFactor = 1.2;
    else if (type.equals("rook")) scaleFactor = 1;
    else if (type.equals("knight")) scaleFactor = 1.5;
    else if (type.equals("bishop")) scaleFactor = 1.5;
    else if (type.equals("queen")&&side.equals("tobis")) scaleFactor = 2.15;
    else if (type.equals("queen")&&side.equals("ham")) scaleFactor = 2;
    else if (type.equals("king")) scaleFactor = 1.15;
    else scaleFactor = 0.9; // default size
  }
  
  void update() {
    float targetX = gridX + col * (tileSize + gap);
    float targetY = gridY + row * (tileSize + gap);
    x += (targetX - x) * 0.3;
    y += (targetY - y) * 0.3;
  }
  
  void display() {
    update();
    float offset = tiles[col][row].offset;
    
    // target box size based on tile, then scale individually
    float baseSize = tileSize * scaleFactor;
    float aspect = (float)img.width / img.height;
    float w, h;
    if (aspect > 1) {
      w = baseSize;
      h = baseSize / aspect;
    } else {
      h = baseSize;
      w = baseSize * aspect;
    }
    
    image(img, 
          x + (tileSize - w)/2 - offset, 
          y + (tileSize - h)/2 - offset, 
          w, h);
  }
}

class AIMove {
  Piece piece;
  int c, r;
  float score;
  AIMove(Piece piece, int c, int r, float score) {
    this.piece = piece; this.c = c; this.r = r; this.score = score;
  }
}

float pieceValue(String type) {
  if (type.equals("king"))   return 100f;
  if (type.equals("queen"))  return 9f;
  if (type.equals("rook"))   return 5f;
  if (type.equals("bishop")) return 3f;
  if (type.equals("knight")) return 3f;
  if (type.equals("pawn"))   return 1f;
  return 0.5f;
}

float evaluateBoard() {
  float score = 0;
  for (int c = 0; c < cols; c++) {
    for (int r = 0; r < rows; r++) {
      Piece p = pieces[c][r];
      if (p == null) continue;
      float val = pieceValue(p.type);
      if (p.side.equals("tobis")) score += val;
      else score -= val;
    }
  }
  return score;
}

float minimax(String side, int depth, float alpha, float beta) {
  if (depth == 0) return evaluateBoard();
  float best = side.equals("tobis") ? -1e9 : 1e9;

  for (int c = 0; c < cols; c++) {
    for (int r = 0; r < rows; r++) {
      Piece p = pieces[c][r];
      if (p == null || !p.side.equals(side)) continue;

      ArrayList<Cell> leg = engine.generateLegalMovesFiltered(p);
      for (Cell mv : leg) {
        // --- make move ---
        Piece captured = pieces[mv.c][mv.r];
        int oc = p.col, or = p.row;
        pieces[oc][or] = null;
        pieces[mv.c][mv.r] = p;
        p.col = mv.c; p.row = mv.r;

        float val = engine.minimax("ham", searchDepth - 1, -1e9, 1e9);

        // --- undo move ---
        p.col = oc; p.row = or;
        pieces[oc][or] = p;
        pieces[mv.c][mv.r] = captured;

        if (side.equals("tobis")) {
          if (val > best) best = val;
          alpha = max(alpha, best);
          if (beta <= alpha) return best; // prune
        } else {
          if (val < best) best = val;
          beta = min(beta, best);
          if (beta <= alpha) return best; // prune
        }
      }
    }
  }

  return best;
}

void runTobisAIMove() {
  if (engine == null || aiThinking) return; // don't start twice

  aiThinking = true;
  aiResult = null;

  // start computeTobisMove() in another thread
  thread("computeTobisMove");
}

void computeTobisMove() {
  Piece[][] boardCopy = engine.cloneBoard(pieces);
  ChessEngine tempEngine = new ChessEngine(boardCopy, cols, rows, "tobis");

  float best = -1e9;
  AIMove bestMove = null;

  for (int c = 0; c < cols; c++) {
    for (int r = 0; r < rows; r++) {
      Piece p = boardCopy[c][r];
      if (p == null || !p.side.equals("tobis")) continue;

      ArrayList<Cell> leg = tempEngine.generateLegalMovesFiltered(p);
      for (Cell mv : leg) {
        // make move on the copy
        Piece captured = boardCopy[mv.c][mv.r];
        int oc = p.col, or = p.row;
        boardCopy[oc][or] = null;
        boardCopy[mv.c][mv.r] = p;
        p.col = mv.c; p.row = mv.r;

        float val = tempEngine.minimax("ham", searchDepth - 1, -1e9, 1e9);

        // undo
        p.col = oc; p.row = or;
        boardCopy[oc][or] = p;
        boardCopy[mv.c][mv.r] = captured;

        if (val > best) {
          best = val;
          // IMPORTANT: keep reference to *real* piece, not the copy
          bestMove = new AIMove(pieces[oc][or], mv.c, mv.r, val);
        }
      }
    }
  }

  aiResult = bestMove; 
  aiThinking = false;
}
