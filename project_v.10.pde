int cols = 10;
int rows = 10;
Tile[][] tiles = new Tile[cols][rows];
Tile activeTile = null;

float gridX, gridY; // top-left corner of grid
float tileSize = 70; // size of each tile
float gap = 2; // spacing between tiles (grid border)

void setup() {
  size(800, 800);
  gridX = (width - cols * (tileSize + gap) + gap) / 2;
  gridY = (height - rows * (tileSize + gap) + gap) / 2;
  
  // create board
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      color c;
      if ((i + j) % 2 == 0) {
        c = color(169, 169, 169); // tile1
      } else {
        c = color(119, 136, 153); // tile2
      }
      float x = gridX + i * (tileSize + gap);
      float y = gridY + j * (tileSize + gap);
      tiles[i][j] = new Tile(x, y, tileSize, tileSize, c);
    }
  }
}

void draw() {
  background(255); // white background
  
  // black square behind the whole grid (borders)
  float gridW = cols * (tileSize + gap) - gap;
  float gridH = rows * (tileSize + gap) - gap;
  fill(0);
  noStroke();
  rect(gridX - gap, gridY - gap, gridW + 2 * gap, gridH + 2 * gap);
  
  // update + draw all tiles
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      tiles[i][j].update();
      tiles[i][j].display();
    }
  }
}

void mousePressed() {
  boolean clickedOnTile = false;
  
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      Tile t = tiles[i][j];
      if (t.isMouseOver()) {
        clickedOnTile = true;
        if (t == activeTile) {
          // clicking the already raised tile will lower it
          t.goDown();
          activeTile = null;
        } else {
          // clicking a different tile
          if (activeTile != null) {
            activeTile.goDown();
          }
          activeTile = t;
          activeTile.goUp();
        }
      }
    }
  }
  
  // clicked outside and it will lower tile
  if (!clickedOnTile && activeTile != null) {
    activeTile.goDown();
    activeTile = null;
  }
}


// Tile class
class Tile {
  float x, y, w, h;
  color c;
  float offset = 0;
  float targetOffset = 0;
  
  Tile(float x, float y, float w, float h, color c) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.c = c;
  }
  
  void update() {
    // animation
    offset += (targetOffset - offset) * 0.1;
  }
  
  void display() {
    pushMatrix();
    translate(-offset, -offset); // shift when selected
    noStroke();
    fill(c);
    rect(x, y, w, h);
    popMatrix();
  }
  
  void goUp() {
    targetOffset = w * 0.1;
  }
  
  void goDown() {
    targetOffset = 0;
  }
  
  boolean isMouseOver() {
    return mouseX > x - offset && mouseX < x + w - offset &&
           mouseY > y - offset && mouseY < y + h - offset;
  }
}
