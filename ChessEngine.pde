// ===================== ChessEngine.pde =====================
import java.util.*;

class Cell {
  int c, r;
  Cell(int c, int r){ this.c=c; this.r=r; }
}

class ChessEngine {
  Piece[][] board;
  int cols, rows;
  String turn; // "ham" or "tobis"
  Piece selected;
  ArrayList<Cell> legal;

  // --- Quiescence search tuning ---
  final int QDEPTH_MAX = 6;
  final int QCAPHARD_CAP = 12;
  final int QEVASION_CAP = 16;
  final float BAD_TRADE_MARGIN = 1.0f;

  ChessEngine(Piece[][] board, int cols, int rows, String startTurn){
    this.board = board;
    this.cols = cols;
    this.rows = rows;
    this.turn = startTurn;
    this.selected = null;
    this.legal = new ArrayList<Cell>();
  }

  // --- Basic interface ---
  String getTurn(){ return turn; }
  Piece getSelected(){ return selected; }
  ArrayList<Cell> getLegal(){ return legal; }

  // Handle user click (select/move/deselect)
  String handleClick(int c, int r){
    if (!inBounds(c,r)) return "noop";
    Piece p = board[c][r];

    if (selected == null){
      if (p != null && p.side.equals(turn)){
        select(p);
        return "selected";
      }
      return "noop";
    }

    if (p == selected){ clearSelection(); return "deselected"; }
    if (isInLegal(c,r)){ moveSelectedTo(c,r); clearSelection(); swapTurn(); return "moved"; }
    if (p != null && p.side.equals(turn)){ select(p); return "selected"; }

    return "noop";
  }

  void select(Piece p){ selected = p; legal = generateLegalMovesFiltered(p); }
  void clearSelection(){ selected = null; legal.clear(); }

  boolean inBounds(int c, int r){ return c >= 0 && c < cols && r >= 0 && r < rows; }
  boolean isInLegal(int c, int r){ for (Cell cell : legal) if (cell.c==c && cell.r==r) return true; return false; }
  void swapTurn(){ turn = turn.equals("ham") ? "tobis" : "ham"; }

  // Commit move
  void moveSelectedTo(int tc, int tr){
    if (selected == null) return;
    board[tc][tr] = selected;
    board[selected.col][selected.row] = null;
    selected.col = tc; selected.row = tr;

    // Pawn promotion
    if (selected.type.equals("pawn")){
      if ((selected.side.equals("ham") && selected.row == 0) ||
          (selected.side.equals("tobis") && selected.row == rows-1)){
        selected.type = "queen";
        selected.img = selected.side.equals("ham") ? hamQueenImg : tobisQueenImg;
        selected.scaleFactor = 2;
      }
    }
  }

  // --- Move generation ---
  ArrayList<Cell> generatePseudoMoves(Piece p){
    ArrayList<Cell> out = new ArrayList<Cell>();
    String side = p.side;

    if (p.type.equals("knight")){
      int[][] d = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
      for (int[] m : d){
        int nc = p.col+m[0], nr=p.row+m[1];
        if (inBounds(nc,nr) && (board[nc][nr]==null || !board[nc][nr].side.equals(side)))
          out.add(new Cell(nc,nr));
      }
    }

    if (p.type.equals("bishop") || p.type.equals("queen")){
      slide(out,p,1,1); slide(out,p,1,-1); slide(out,p,-1,1); slide(out,p,-1,-1);
    }
    if (p.type.equals("rook") || p.type.equals("queen")){
      slide(out,p,1,0); slide(out,p,-1,0); slide(out,p,0,1); slide(out,p,0,-1);
    }

    if (p.type.equals("king")){
      int[][] d = {{1,1},{1,0},{1,-1},{0,1},{0,-1},{-1,1},{-1,0},{-1,-1}};
      for (int[] m : d){
        int nc=p.col+m[0], nr=p.row+m[1];
        if (inBounds(nc,nr) && (board[nc][nr]==null || !board[nc][nr].side.equals(side)))
          out.add(new Cell(nc,nr));
      }
    }

    if (p.type.equals("pawn")){
      int dir = side.equals("ham") ? -1 : 1;
      int startRow = side.equals("ham") ? rows-2 : 1;

      int f1c = p.col, f1r = p.row + dir;
      if (inBounds(f1c,f1r) && board[f1c][f1r]==null){
        out.add(new Cell(f1c,f1r));
        int f2r = p.row + 2*dir;
        if (p.row==startRow && inBounds(f1c,f2r) && board[f1c][f2r]==null)
          out.add(new Cell(f1c,f2r));
      }

      for (int dc=-1; dc<=1; dc+=2){
        int nc=p.col+dc, nr=p.row+dir;
        if (inBounds(nc,nr) && board[nc][nr]!=null && !board[nc][nr].side.equals(side))
          out.add(new Cell(nc,nr));
      }
    }

    return out;
  }

  void slide(ArrayList<Cell> out, Piece p, int dc, int dr){
    int nc=p.col+dc, nr=p.row+dr;
    while (inBounds(nc,nr)){
      if (board[nc][nr]==null) out.add(new Cell(nc,nr));
      else {
        if (!board[nc][nr].side.equals(p.side)) out.add(new Cell(nc,nr));
        break;
      }
      nc+=dc; nr+=dr;
    }
  }

  // --- Check filtering ---
  ArrayList<Cell> generateLegalMovesFiltered(Piece p){
    ArrayList<Cell> raw = generatePseudoMoves(p);
    ArrayList<Cell> filtered = new ArrayList<Cell>();
    for (Cell mv : raw){
      Piece captured = board[mv.c][mv.r];
      int oc=p.col, or=p.row;
      board[mv.c][mv.r]=p; board[oc][or]=null;
      p.col=mv.c; p.row=mv.r;
      boolean ok=!isKingInCheck(p.side);
      p.col=oc; p.row=or;
      board[oc][or]=p; board[mv.c][mv.r]=captured;
      if (ok) filtered.add(mv);
    }
    return filtered;
  }

  boolean isKingInCheck(String side){
    Cell k=findKing(side);
    if (k==null) return false;
    return squareAttackedBy(k.c,k.r,opposite(side));
  }

  Cell findKing(String side){
    for (int c=0;c<cols;c++)
      for (int r=0;r<rows;r++){
        Piece p=board[c][r];
        if (p!=null && p.side.equals(side) && p.type.equals("king"))
          return new Cell(c,r);
      }
    return null;
  }

  String opposite(String s){ return s.equals("ham") ? "tobis" : "ham"; }

  boolean squareAttackedBy(int tc, int tr, String attackerSide){
    // Knight
    int[][] kn={{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m:kn){
      int c=tc+m[0],r=tr+m[1];
      if (inBounds(c,r)){
        Piece p=board[c][r];
        if (p!=null && p.side.equals(attackerSide) && p.type.equals("knight")) return true;
      }
    }
    // King
    int[][] kg={{1,1},{1,0},{1,-1},{0,1},{0,-1},{-1,1},{-1,0},{-1,-1}};
    for (int[] m:kg){
      int c=tc+m[0],r=tr+m[1];
      if (inBounds(c,r)){
        Piece p=board[c][r];
        if (p!=null && p.side.equals(attackerSide) && p.type.equals("king")) return true;
      }
    }
    // Rook/Queen
    if (rayHits(tc,tr,1,0,attackerSide,"rook","queen")) return true;
    if (rayHits(tc,tr,-1,0,attackerSide,"rook","queen")) return true;
    if (rayHits(tc,tr,0,1,attackerSide,"rook","queen")) return true;
    if (rayHits(tc,tr,0,-1,attackerSide,"rook","queen")) return true;
    // Bishop/Queen
    if (rayHits(tc,tr,1,1,attackerSide,"bishop","queen")) return true;
    if (rayHits(tc,tr,1,-1,attackerSide,"bishop","queen")) return true;
    if (rayHits(tc,tr,-1,1,attackerSide,"bishop","queen")) return true;
    if (rayHits(tc,tr,-1,-1,attackerSide,"bishop","queen")) return true;
    // Pawns
    int dir = attackerSide.equals("ham") ? -1 : 1;
    int pr = tr - dir;
    for (int dc=-1; dc<=1; dc+=2){
      int pc = tc + dc;
      if (inBounds(pc,pr)){
        Piece p = board[pc][pr];
        if (p != null && p.side.equals(attackerSide) && p.type.equals("pawn")) return true;
      }
    }
    return false;
  }

  boolean rayHits(int tc, int tr, int dc, int dr, String side, String t1, String t2){
    int c=tc+dc, r=tr+dr;
    while(inBounds(c,r)){
      Piece p=board[c][r];
      if(p!=null){
        if(p.side.equals(side)&&(p.type.equals(t1)||p.type.equals(t2))) return true;
        return false;
      }
      c+=dc; r+=dr;
    }
    return false;
  }

  // Checkmate/Stalemate
  boolean noLegalMovesFor(String side){
    for (int c=0;c<cols;c++)
      for (int r=0;r<rows;r++){
        Piece p=board[c][r];
        if (p!=null && p.side.equals(side) && generateLegalMovesFiltered(p).size()>0)
          return false;
      }
    return true;
  }

  boolean isCheckmate(String side){ return isKingInCheck(side) && noLegalMovesFor(side); }
  boolean isStalemate(String side){ return !isKingInCheck(side) && noLegalMovesFor(side); }
  //evaluation
// --- Phase weights ---
final float TEMPO_BONUS = 0.10f;   // small nudge for side to move (helps initiative)
final float BISHOP_PAIR = 0.30f;   // bishop pair bonus
final float DOUBLED_PAWN = 0.18f;
final float ISOLATED_PAWN = 0.18f;
final float PASSED_PAWN  = 0.22f;

// If quiescence made things slow/erratic early, slightly tighten it:
final int   QDEPTH_MAX_TUNED   = 4;
final int   QCAPHARD_CAP_TUNED = 10;
final int   QEVASION_CAP_TUNED = 12;
final float BAD_TRADE_MARGIN_TUNED = 0.5f;

// idk i got this online:
void tuneQParams(){
  // only if you want to adopt the tighter settings:
  // (or just replace your top-level constants with these values)
  // QDEPTH_MAX   = QDEPTH_MAX_TUNED;      // if not final
  // QCAPHARD_CAP = QCAPHARD_CAP_TUNED;
  // QEVASION_CAP = QEVASION_CAP_TUNED;
  // BAD_TRADE_MARGIN = BAD_TRADE_MARGIN_TUNED;
}

// Blends opening and endgame scores based on remaining material.
float evaluate() {
  // Material phase: pawns contribute little, majors a lot.
  int phase = 0, phaseMax = 0;
  float matMid = 0, matEnd = 0;

  int hamBishops = 0, tobisBishops = 0;
  int hamKnightsDev = 0, tobisKnightsDev = 0;
  int hamBishopsDev = 0, tobisBishopsDev = 0;

  // file-wise pawn data for structure terms
  int[] hamPawnsInFile  = new int[cols];
  int[] tobisPawnsInFile= new int[cols];

  // Precompute center for PSQT
  float cx = (cols - 1) * 0.5f, cy = (rows - 1) * 0.5f;

  for (int c=0; c<cols; c++){
    for (int r=0; r<rows; r++){
      Piece p = board[c][r];
      if (p == null) continue;

      float base = pieceValue(p.type);
      // Phase accounting (inspired by common schemes)
      int ph = 0;
      if (p.type.equals("pawn"))   ph = 0;
      else if (p.type.equals("knight") || p.type.equals("bishop")) ph = 1;
      else if (p.type.equals("rook"))   ph = 2;
      else if (p.type.equals("queen"))  ph = 4;
      phase += ph; phaseMax += 4; // rough scaling

      // Opening/endgame piece-square
      float psMid = psqtMid(p, c, r, cx, cy);
      float psEnd = psqtEnd(p, c, r, cx, cy);

      // Development bookkeeping
      boolean onBack = (p.side.equals("tobis") ? r == 0 : r == rows-1);
      if (p.type.equals("knight")){
        if (!onBack) {
          if (p.side.equals("tobis")) tobisKnightsDev++; else hamKnightsDev++;
        }
      }
      if (p.type.equals("bishop")){
        if (p.side.equals("tobis")) tobisBishops++; else hamBishops++;
        if (!onBack) {
          if (p.side.equals("tobis")) tobisBishopsDev++; else hamBishopsDev++;
        }
      }

      // Pawn structure counts
      if (p.type.equals("pawn")){
        if (p.side.equals("tobis")) tobisPawnsInFile[c]++;
        else hamPawnsInFile[c]++;
      }

      // Sum material + PSQT into the correct side buckets
      float termMid = base + psMid;
      float termEnd = base + psEnd;

      if (p.side.equals("tobis")) { matMid += termMid; matEnd += termEnd; }
      else { matMid -= termMid; matEnd -= termEnd; }
    }
  }

  // Bishop pair
  if (tobisBishops >= 2) { matMid += BISHOP_PAIR; matEnd += BISHOP_PAIR; }
  if (hamBishops   >= 2) { matMid -= BISHOP_PAIR; matEnd -= BISHOP_PAIR; }

  //[Chess game weights got this on stack overflow]

  // Development & opening sanity (only meaningful early → scale by phaseBlend)
  float phaseBlend = clamp01(phase / max(1f, (float)phaseMax));   // 0..1 (more material → closer to 1)
  float openingWeight = phaseBlend;                               // 1 = opening, 0 = endgame
  float endgameWeight = 1f - openingWeight;

  // Minor undeveloped penalties on back rank (opening only)
  float undevelopedMinor = 0.15f;
  matMid += openingWeight * (tobisKnightsDev + tobisBishopsDev) * 0.06f; // reward development
  matMid -= openingWeight * (hamKnightsDev + hamBishopsDev) * 0.06f;

  // Early-queen penalty: if side has <2 minors developed and queen is off back rank, penalize
  matMid += openingWeight * earlyQueenPenalty("tobis");
  matMid -= openingWeight * earlyQueenPenalty("ham");

  // Center pawn “blocked start” nudges (encourage e/d pawns to move or be unblocked)
  matMid += openingWeight * centerPawnNudge("tobis");
  matMid -= openingWeight * centerPawnNudge("ham");

  // Pawn structure (both phases)
  float strTobis = pawnStructureScore(tobisPawnsInFile, "tobis");
  float strHam   = pawnStructureScore(hamPawnsInFile,   "ham");
  matMid += strTobis - strHam; matEnd += (strTobis - strHam) * 0.8f; // a bit less important late

  // Tempo (side to move = 'turn' == "tobis" is maximizing in your search)
  if ("tobis".equals(turn)) { matMid += TEMPO_BONUS * openingWeight; }
  else { matMid -= TEMPO_BONUS * openingWeight; }

  // Blend opening/endgame totals
  float score = openingWeight * matMid + endgameWeight * matEnd;
  return score;
}




// Helper: move ordering
ArrayList<Cell> orderedMoves(Piece p) {
  ArrayList<Cell> moves = generateLegalMovesFiltered(p);
  final String side = p.side;
  final boolean opening = isOpeningPhase();

  moves.sort(new Comparator<Cell>() {
    public int compare(Cell a, Cell b) {
      int sa = moveScore(p, a, side, opening);
      int sb = moveScore(p, b, side, opening);
      return Integer.compare(sb, sa); // high → low
    }
  });
  return moves;
}

boolean isOpeningPhase(){
  // reuse the phase idea from eval, but cheaper:
  int material = 0;
  for (int c=0;c<cols;c++) for (int r=0;r<rows;r++){
    Piece q = board[c][r];
    if (q==null) continue;
    if (q.type.equals("queen")) material += 4;
    else if (q.type.equals("rook")) material += 2;
    else if (q.type.equals("knight") || q.type.equals("bishop")) material += 1;
  }
  // larger number → more opening; tune threshold for your board size
  return material > (cols >= 10 ? 28 : 20);
}

int moveScore(Piece p, Cell mv, String side, boolean opening){
  int score = 0;
  Piece target = board[mv.c][mv.r];

  // MVV-LVA for captures
  if (target != null){
    int victim = round(pieceValue(target.type) * 100);
    int attacker = round(pieceValue(p.type) * 100);
    score += (victim * 10 - attacker);
  }

  if (opening){
    int back = side.equals("tobis") ? 0 : rows-1;
    // encourage developing minors off back rank
    if ((p.type.equals("knight") || p.type.equals("bishop")) && p.row == back && mv.r != back) score += 50;

    // encourage centralizing minors
    int center1 = cols/2, center2 = (cols%2==0)? center1-1:center1;
    if ((p.type.equals("knight") || p.type.equals("bishop")) && (mv.c==center1 || mv.c==center2)) score += 20;

    // discourage early queen sorties
    if (p.type.equals("queen") && p.row == back && mv.r != back) score -= 40;

    // encourage pushing center pawns from start
    int startRow = side.equals("tobis") ? 1 : rows-2;
    if (p.type.equals("pawn") && p.row == startRow){
      int eFile = cols/2, dFile = (cols%2==0)? eFile-1:eFile;
      if (p.col==dFile || p.col==eFile) score += 25;
    }
  }

  return score;
}


float quiescence(String side, float alpha, float beta, int qDepth) {
  float stand = evaluate(); // tobis perspective

  // Stand-pat cut/raise bounds based on the side to move
  if (side.equals("tobis")) {
    if (stand >= beta) return stand;   // fail-high
    if (stand > alpha) alpha = stand;  // raise lower bound
  } else {
    if (stand <= alpha) return stand;  // fail-low
    if (stand < beta) beta = stand;    // lower upper bound
  }

  // Depth cap for safety
  if (qDepth >= QDEPTH_MAX) return side.equals("tobis") ? alpha : beta;

  // If in check, allow *all* legal evasions (not just captures), but cap count
  if (isKingInCheck(side)) {
    int explored = 0;
    for (int c = 0; c < cols; c++) for (int r = 0; r < rows; r++) {
      Piece p = board[c][r];
      if (p == null || !p.side.equals(side)) continue;
      ArrayList<Cell> legalMoves = generateLegalMovesFiltered(p);
      for (Cell mv : legalMoves) {
        if (++explored > QEVASION_CAP) return side.equals("tobis") ? alpha : beta;

        Piece captured = board[mv.c][mv.r];
        int oc = p.col, or = p.row;

        // make
        board[oc][or] = null; board[mv.c][mv.r] = p; p.col = mv.c; p.row = mv.r;

        float sc = quiescence(opposite(side), alpha, beta, qDepth + 1);

        // undo
        p.col = oc; p.row = or; board[oc][or] = p; board[mv.c][mv.r] = captured;

        if (side.equals("tobis")) {
          if (sc > alpha) alpha = sc;
        } else {
          if (sc < beta) beta = sc;
        }
        if (alpha >= beta) return side.equals("tobis") ? alpha : beta; // cutoff
      }
    }
    return side.equals("tobis") ? alpha : beta;
  }

  // Otherwise: capture-only search
  int capCount = 0;
  for (int c = 0; c < cols; c++) for (int r = 0; r < rows; r++) {
    Piece p = board[c][r];
    if (p == null || !p.side.equals(side)) continue;

    ArrayList<Cell> caps = captureMovesOrdered(p);
    for (Cell mv : caps) {
      Piece victim = board[mv.c][mv.r];
      if (victim == null) continue;

      // Simple static-exchange pruning: skip obviously losing captures
      if (pieceValue(p.type) > pieceValue(victim.type) + BAD_TRADE_MARGIN) continue;

      if (++capCount > QCAPHARD_CAP) return side.equals("tobis") ? alpha : beta;

      int oc = p.col, or = p.row;
      // make
      board[oc][or] = null; board[mv.c][mv.r] = p; p.col = mv.c; p.row = mv.r;

      float sc = quiescence(opposite(side), alpha, beta, qDepth + 1);

      // undo
      p.col = oc; p.row = or; board[oc][or] = p; board[mv.c][mv.r] = victim;

      if (side.equals("tobis")) {
        if (sc > alpha) alpha = sc;
      } else {
        if (sc < beta) beta = sc;
      }
      if (alpha >= beta) return side.equals("tobis") ? alpha : beta; // cutoff
    }
  }

  return side.equals("tobis") ? alpha : beta;
}


// Replace your depth==0 base case to call quiescence (no negation!)
float minimax(String side, int depth, float alpha, float beta) {
  if (depth == 0) return quiescence(side, alpha, beta, 0);

  boolean maximizing = side.equals("tobis");
  float best = maximizing ? -1e9f : 1e9f;

  for (int c = 0; c < cols; c++) {
    for (int r = 0; r < rows; r++) {
      Piece p = board[c][r];
      if (p == null || !p.side.equals(side)) continue;

      ArrayList<Cell> moves = orderedMoves(p); // your existing capture-first ordering
      for (Cell mv : moves) {
        Piece captured = board[mv.c][mv.r];
        int oc = p.col, or = p.row;

        // make
        board[oc][or] = null; board[mv.c][mv.r] = p; p.col = mv.c; p.row = mv.r;

        float val = minimax(opposite(side), depth - 1, alpha, beta);

        // undo
        p.col = oc; p.row = or; board[oc][or] = p; board[mv.c][mv.r] = captured;

        if (maximizing) {
          if (val > best) best = val;
          if (best > alpha) alpha = best;
        } else {
          if (val < best) best = val;
          if (best < beta) beta = best;
        }

        if (beta <= alpha) return best; // prune
      }
    }
  }
  return best;
}


// Make a deep copy of a board state for ches engine
Piece[][] cloneBoard(Piece[][] original) {
  Piece[][] copy = new Piece[cols][rows];
  for (int c = 0; c < cols; c++) {
    for (int r = 0; r < rows; r++) {
      Piece p = original[c][r];
      if (p != null) {
        // copy only the essential data
        Piece np = new Piece(p.img, p.col, p.row, p.type, p.side);
        np.scaleFactor = p.scaleFactor;
        copy[c][r] = np;
      }
    }
  }
  return copy;
}

float clamp01(float x){ return x < 0 ? 0 : (x > 1 ? 1 : x); }

// Dynamic PSQT for midgame: reward centralization & space; keep cheap math
float psqtMid(Piece p, int c, int r, float cx, float cy){
  float dx = abs(c - cx), dy = abs(r - cy);
  float dist = dx + dy; // Manhattan distance to center
  float centerBonus = (5f - dist) * 0.10f; // fades with size automatically

  float rankAdvance = 0;
  if (p.type.equals("pawn")){
    rankAdvance = (p.side.equals("tobis") ? r : (rows - 1 - r)) * 0.05f;
    // prefer center files slightly for pawns
    float fileCenter = (abs(c - cx) <= 0.5f) ? 0.10f : 0f;
    return centerBonus + rankAdvance + fileCenter;
  }
  if (p.type.equals("knight")) return centerBonus * 1.2f;
  if (p.type.equals("bishop")) return centerBonus * 1.0f;
  if (p.type.equals("rook"))   return (0.06f * openFileBonus(p, c)) + 0.02f * mobilityCheap(p);
  if (p.type.equals("queen"))  return 0.04f * mobilityCheap(p);
  if (p.type.equals("king"))   return -0.25f * (p.side.equals("tobis") ? r : (rows - 1 - r)); // prefer back rank early
  return 0;
}

// Endgame: centralize king, push passed pawns; other pieces modestly central
float psqtEnd(Piece p, int c, int r, float cx, float cy){
  float dx = abs(c - cx), dy = abs(r - cy);
  float center = (5f - (dx + dy)) * 0.06f;

  if (p.type.equals("king")) return center * 2.0f; // king wants to be active
  if (p.type.equals("pawn")) return ((p.side.equals("tobis") ? r : (rows - 1 - r)) * 0.06f);
  if (p.type.equals("rook")) return 0.04f * mobilityCheap(p);
  if (p.type.equals("queen"))return 0.03f * mobilityCheap(p);
  return center * 0.6f;
}

// Very cheap mobility proxy (don’t generate full legal moves—too slow in eval)
int mobilityCheap(Piece p){
  // just count empty rays/knight jumps without legality filtering
  int cnt = 0;
  if (p.type.equals("knight")){
    int[][] d = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m : d){
      int nc = p.col + m[0], nr = p.row + m[1];
      if (inBounds(nc,nr) && (board[nc][nr] == null || !board[nc][nr].side.equals(p.side))) cnt++;
    }
    return cnt;
  }
  if (p.type.equals("bishop") || p.type.equals("rook") || p.type.equals("queen")){
    int[][] rays = (p.type.equals("bishop")) ?
      new int[][]{{1,1},{1,-1},{-1,1},{-1,-1}} :
      (p.type.equals("rook")) ?
      new int[][]{{1,0},{-1,0},{0,1},{0,-1}} :
      new int[][]{{1,1},{1,-1},{-1,1},{-1,-1},{1,0},{-1,0},{0,1},{0,-1}};
    for (int[] d : rays){
      int nc = p.col + d[0], nr = p.row + d[1];
      while (inBounds(nc,nr)){
        cnt++;
        if (board[nc][nr] != null) break;
        nc += d[0]; nr += d[1];
      }
    }
  }
  return cnt;
}

// Open/semi-open file bonus for rooks
int openFileBonus(Piece p, int file){
  if (!p.type.equals("rook")) return 0;
  boolean myPawn = false, oppPawn = false;
  for (int r=0; r<rows; r++){
    Piece q = board[file][r];
    if (q != null && q.type.equals("pawn")){
      if (q.side.equals(p.side)) myPawn = true; else oppPawn = true;
    }
  }
  if (!myPawn && !oppPawn) return 2;   // open
  if (!myPawn && oppPawn)   return 1;  // semi-open
  return 0;
}

// Early-queen penalty if <2 minors developed and queen left back rank
float earlyQueenPenalty(String side){
  int minorsDev = 0;
  boolean queenOffBack = false;
  int back = side.equals("tobis") ? 0 : rows-1;

  for (int c=0;c<cols;c++){
    for (int r=0;r<rows;r++){
      Piece p = board[c][r];
      if (p==null || !p.side.equals(side)) continue;
      if (p.type.equals("knight") || p.type.equals("bishop")){
        if (r != back) minorsDev++;
      } else if (p.type.equals("queen")){
        if (r != back) queenOffBack = true;
      }
    }
  }
  if (queenOffBack && minorsDev < 2) return -0.30f;
  return 0f;
}

// Encourage freeing center pawns (like d/e) or not blocking them with own pieces
float centerPawnNudge(String side){
  int eFile = cols/2;
  int dFile = (cols%2==0) ? eFile-1 : eFile;
  float s = 0;
  s += unblockedForwardPawn(side, dFile) ? 0.08f : -0.04f;
  s += unblockedForwardPawn(side, eFile) ? 0.08f : -0.04f;
  return s;
}
boolean unblockedForwardPawn(String side, int file){
  int dir = side.equals("tobis") ? 1 : -1;
  int start = side.equals("tobis") ? 1 : rows-2;
  // is there a pawn on its start square?
  Piece p = board[file][start];
  if (p == null || !p.side.equals(side) || !p.type.equals("pawn")) return true; // no pawn → neutral
  int one = start + dir;
  return inBounds(file, one) && board[file][one] == null;
}

// [Pasted and modified from stack overflow]

// Pawn structure over all files
float pawnStructureScore(int[] pawnsInFile, String side){
  float s = 0;
  for (int f=0; f<cols; f++){
    int n = pawnsInFile[f];
    if (n > 1) s -= DOUBLED_PAWN * (n - 1);
    boolean iso =
      (f==0    ? pawnsInFile[f+1]==0 :
       f==cols-1 ? pawnsInFile[f-1]==0 :
       (pawnsInFile[f-1]==0 && pawnsInFile[f+1]==0));
    if (n >= 1 && iso) s -= ISOLATED_PAWN;

    // quick passed-pawn check
    if (n >= 1 && isPassedFile(side, f)) s += PASSED_PAWN;
  }
  return s;
}

boolean isPassedFile(String side, int f){
  int dir = side.equals("tobis") ? 1 : -1;
  // scan all pawns; if any opposing pawn is on same/adjacent file *ahead* of ours, not passed
  for (int c = max(0, f-1); c <= min(cols-1, f+1); c++){
    for (int r=0; r<rows; r++){
      Piece q = board[c][r];
      if (q == null || !q.type.equals("pawn")) continue;
      if (side.equals(q.side)) continue;
      // ahead relative to 'side'
      if ( (side.equals("tobis") && r >= 0) || (side.equals("ham") && r <= rows-1) ){
        // we just need to ensure there exists a friendly pawn ahead; handled implicitly when called
      }
    }
  }
  // Simple & fast: check board for *any* enemy pawn on same/adjacent file in front sectors
  for (int c = max(0, f-1); c <= min(cols-1, f+1); c++){
    for (int r=0; r<rows; r++){
      Piece q = board[c][r];
      if (q == null || !q.type.equals("pawn") || side.equals(q.side)) continue;
      if (side.equals("tobis")) {
        // enemy pawn blocks if it is at or below our future path (greater r)
        // since we didn’t track our pawn rank here, approximate: existence → reduce reliability slightly elsewhere
        // keep it simple: treat as not passed if any enemy pawn exists on these files
        return false;
      } else {
        return false;
      }
    }
  }
  return true; // very light heuristic
}


}
