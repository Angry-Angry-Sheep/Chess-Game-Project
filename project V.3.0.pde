int cols = 10;
int rows = 10;
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

void setup() {
  size(800, 800);

  // Load Ham pieces
  hamKnightImg = loadImage("HamKnight.png");
  hamQueenImg  = loadImage("HamQueen.png");
  hamBishopImg = loadImage("HamBishop.png");
  hamPawnImg   = loadImage("HamPawn.png");
  hamRookImg   = loadImage("HamRook.png");
  hamKingImg   = loadImage("KingHam.png");

  // Load Tobis pieces
  tobisKnightImg = loadImage("TobisKnight.png");
  tobisQueenImg  = hamQueenImg; // replace with Tobis queen
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

  // Place Ham pieces
  pieces[0][9] = new Piece(hamRookImg, 0, 9, "rook", "ham");
  pieces[1][9] = new Piece(hamKnightImg, 1, 9, "knight", "ham");
  pieces[2][9] = new Piece(hamBishopImg, 2, 9, "bishop", "ham");
  pieces[3][9] = new Piece(hamBishopImg, 3, 9, "bishop", "ham");
  pieces[8][9] = new Piece(hamKnightImg, 8, 9, "knight", "ham");
  pieces[7][9] = new Piece(hamBishopImg, 7, 9, "bishop", "ham");
  pieces[6][9] = new Piece(hamBishopImg, 6, 9, "bishop", "ham");
  pieces[4][9] = new Piece(hamQueenImg, 4, 9, "queen", "ham");
  pieces[9][9] = new Piece(hamRookImg, 9, 9, "rook", "ham");
  pieces[5][9] = new Piece(hamKingImg, 5, 9, "king", "ham");
  for (int i = 0; i < cols; i++) {
    pieces[i][8] = new Piece(hamPawnImg, i, 8, "pawn", "ham");
  }

  // Place Tobis pieces
  pieces[0][0] = new Piece(tobisRookImg, 0, 0, "rook", "tobis");
  pieces[1][0] = new Piece(tobisKnightImg, 1, 0, "knight", "tobis");
  pieces[2][0] = new Piece(tobisBishopImg, 2, 0, "bishop", "tobis");
  pieces[3][0] = new Piece(tobisBishopImg, 3, 0, "bishop", "tobis");
  pieces[8][0] = new Piece(tobisKnightImg, 8, 0, "knight", "tobis");
  pieces[6][0] = new Piece(tobisBishopImg, 6, 0, "bishop", "tobis");
  pieces[7][0] = new Piece(tobisBishopImg, 7, 0, "bishop", "tobis");
  pieces[5][0] = new Piece(tobisQueenImg, 5, 0, "queen", "tobis");
  pieces[9][0] = new Piece(tobisRookImg, 9, 0, "rook", "tobis");
  pieces[4][0] = new Piece(tobisKingImg, 4, 0, "king", "tobis");
  for (int i = 0; i < cols; i++) {
    pieces[i][1] = new Piece(tobisPawnImg, i, 1, "pawn", "tobis");
  }
}

void draw() {
  background(255); // white background
  
  // black border behind board
  float gridW = cols * (tileSize + gap) - gap;
  float gridH = rows * (tileSize + gap) - gap;
  fill(0);
  noStroke();
  rect(gridX - gap, gridY - gap, gridW + 2 * gap, gridH + 2 * gap);
  
  // draw tiles
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      tiles[i][j].update();
      tiles[i][j].display();
    }
  }

  // draw pieces
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      if (pieces[i][j] != null) {
        pieces[i][j].display();
      }
    }
  }
}

void mousePressed() {
  int clickedCol = -1, clickedRow = -1;

  // find clicked tile
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

  if (selectedPiece == null) {
    if (p != null) {
      selectPiece(p);
    } else {
      if (activeTile == clickedTile) {
        deselectAll();
      } else {
        deselectAll();
        activeTile = clickedTile;
        activeTile.goUp();
      }
    }
  } else {
    if (selectedPiece.col == clickedCol && selectedPiece.row == clickedRow) {
      // clicking same piece deselects
      deselectAll();
    } else if (tiles[clickedCol][clickedRow].highlighted) {
      // move piece
      pieces[selectedPiece.col][selectedPiece.row] = null;
      selectedPiece.col = clickedCol;
      selectedPiece.row = clickedRow;

      // ===== Pawn Promotion Check =====
      if (selectedPiece.type.equals("pawn")) {
        if ((selectedPiece.side.equals("ham") && selectedPiece.row == 0) ||
            (selectedPiece.side.equals("tobis") && selectedPiece.row == rows - 1)) {
          // Promote to queen
          selectedPiece.type = "queen";
          selectedPiece.img = selectedPiece.side.equals("ham") ? hamQueenImg : tobisQueenImg;
          selectedPiece.scaleFactor = 2; // same scaling you used for queens
        }
      }
      // ================================

      pieces[clickedCol][clickedRow] = selectedPiece;
      deselectAll();
    } else {
      // clicked elsewhere
      deselectAll();
      if (p != null) {
        selectPiece(p);
      } else {
        activeTile = clickedTile;
        activeTile.goUp();
      }
    }
  }
}


void selectPiece(Piece p) {
  deselectAll();
  selectedPiece = p;
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
  int startRow = p.side.equals("ham") ? 8 : 1; // ham pawns at row 8, tobis pawns at row 1

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
  if (selectedPiece != null) {
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        tiles[i][j].goDown();
      }
    }
    selectedPiece = null;
  }
  if (activeTile != null) {
    activeTile.goDown();
    activeTile = null;
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
    else if (type.equals("queen")) scaleFactor = 2;
    else if (type.equals("king")) scaleFactor = 1.15;
    else scaleFactor = 0.9; // default (e.g. king or unknown)
  }
  
  void update() {
    float targetX = gridX + col * (tileSize + gap);
    float targetY = gridY + row * (tileSize + gap);
    x += (targetX - x) * 0.2;
    y += (targetY - y) * 0.2;
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
