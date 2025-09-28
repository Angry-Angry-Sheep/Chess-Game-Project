int cols = 10;
int rows = 10;
Tile[][] tiles = new Tile[cols][rows];
Tile activeTile = null;

float gridX, gridY; // top-left corner of grid
float tileSize = 70; // size of each tile
float gap = 2; // spacing between tiles (grid border)

// Piece images
PImage knightImg, queenImg, bishopImg;

// Pieces array
Piece[][] pieces = new Piece[cols][rows];

Piece selectedPiece = null;

void setup() {
  size(800, 800);

  knightImg = loadImage("HamKnight.png");
  queenImg  = loadImage("HamQueen.png");
  bishopImg = loadImage("HamBishop.png");

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

  // Place some pieces for testing
  pieces[0][0] = new Piece(knightImg, 0, 0, "knight");
  pieces[1][0] = new Piece(queenImg, 1, 0, "queen");
  pieces[2][0] = new Piece(bishopImg, 2, 0, "bishop");

  pieces[0][9] = new Piece(knightImg, 0, 9, "knight");
  pieces[1][9] = new Piece(queenImg, 1, 9, "queen");
  pieces[2][9] = new Piece(bishopImg, 2, 9, "bishop");
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
    deselectPiece();
    return;
  }

  Piece p = pieces[clickedCol][clickedRow];

  if (selectedPiece == null) {
    // select piece if present
    if (p != null) {
      selectPiece(p);
    }
  } else {
    if (selectedPiece.col == clickedCol && selectedPiece.row == clickedRow) {
      // clicked same piece = deselect
      deselectPiece();
    } else if (tiles[clickedCol][clickedRow].highlighted) {
      // move piece
      pieces[selectedPiece.col][selectedPiece.row] = null;
      selectedPiece.col = clickedCol;
      selectedPiece.row = clickedRow;
      pieces[clickedCol][clickedRow] = selectedPiece;
      deselectPiece();
    } else {
      deselectPiece();
      if (p != null) {
        selectPiece(p);
      }
    }
  }
}

void selectPiece(Piece p) {
  deselectPiece(); // clear old highlighed tiles
  selectedPiece = p;
  // highlight the current tile
  tiles[p.col][p.row].goUpHighlight();

  // add simple move highlights
  if (p.type.equals("knight")) {
    int[][] moves = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m : moves) {
      int nc = p.col + m[0];
      int nr = p.row + m[1];
      if (inBounds(nc,nr)) {
        tiles[nc][nr].goUpHighlight();
      }
    }
  } else if (p.type.equals("bishop")) {
    for (int d = -1; d <= 1; d+=2) {
      for (int e = -1; e <= 1; e+=2) {
        for (int step = 1; step < 10; step++) {
          int nc = p.col + step*d;
          int nr = p.row + step*e;
          if (!inBounds(nc,nr)) break;
          tiles[nc][nr].goUpHighlight();
        }
      }
    }
  } else if (p.type.equals("queen")) {
    // rook movement
    for (int i = 0; i < cols; i++) {
      if (i != p.col) tiles[i][p.row].goUpHighlight();
    }
    for (int j = 0; j < rows; j++) {
      if (j != p.row) tiles[p.col][j].goUpHighlight();
    }
    // bishop movement
    for (int d = -1; d <= 1; d+=2) {
      for (int e = -1; e <= 1; e+=2) {
        for (int step = 1; step < 10; step++) {
          int nc = p.col + step*d;
          int nr = p.row + step*e;
          if (!inBounds(nc,nr)) break;
          tiles[nc][nr].goUpHighlight();
        }
      }
    }
  }
}

void deselectPiece() {
  if (selectedPiece != null) {
    // reset all highlighted tiles
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < rows; j++) {
        tiles[i][j].goDown();
      }
    }
  }
  selectedPiece = null;
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
    offset += (targetOffset - offset) * 0.1;
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
    // SELECTED COLOR
    currentColor = lerpColor(baseColor, color(255), 0.6);
    highlighted = true;
  }
  
  void goDown() {
    targetOffset = 0;
    currentColor = baseColor;
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
  String type;
  
  Piece(PImage img, int col, int row, String type) {
    this.img = img;
    this.col = col;
    this.row = row;
    this.type = type;
  }
  
  void display() {
    float baseX = gridX + col * (tileSize + gap);
    float baseY = gridY + row * (tileSize + gap);
    float offset = tiles[col][row].offset;
    
    // PIECE SIZE
    float scaleFactor = tileSize * 1.5 / max(img.width, img.height);
    float w = img.width * scaleFactor;
    float h = img.height * scaleFactor;
    
    image(img, baseX + (tileSize - w)/2 - offset, 
               baseY + (tileSize - h)/2 - offset, 
               w, h);
  }
}
