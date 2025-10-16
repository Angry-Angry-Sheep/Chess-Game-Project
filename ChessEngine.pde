import java.util.*;

class Cell {
  int c, r;
  Cell(int c, int r){ this.c=c; this.r=r; }
}

class ChessEngine {
  Piece[][] board;
  int cols, rows;
  String turn;
  Piece selected;
  ArrayList<Cell> legal;// legal moves
  // Simple per-node eval cache
  HashMap<Long, Float> evalCache = new HashMap<Long, Float>();

  
    // -- Tuning knobs --
  final int QDEPTH_MAX = 6; // max quiescence plies
  final int QCAPHARD_CAP = 12; // max captures per node
  final int QEVASION_CAP = 16; // max evasions when in check
  final float BAD_TRADE_MARGIN = 1.0f; // skip captures that hang material (in piece-value units)
  
  
  // returns only capture moves for p. Is a helper
  ArrayList<Cell> captureMovesOrdered(Piece p) {
    ArrayList<Cell> all = generateLegalMovesFiltered(p);
    ArrayList<Cell> caps = new ArrayList<Cell>();
    for (Cell mv : all) {
      if (board[mv.c][mv.r] != null) caps.add(mv);
    }
    caps.sort(new Comparator<Cell>() {
      public int compare(Cell a, Cell b) {
        Piece va = board[a.c][a.r], vb = board[b.c][b.r];
        float sa = (va != null ? pieceValue(va.type) : 0) - 0.1f * pieceValue(p.type);
        float sb = (vb != null ? pieceValue(vb.type) : 0) - 0.1f * pieceValue(p.type);
        return Float.compare(sb, sa); // higher MVV-LVA first
      }
    });
    return caps;
  }
  // Transposition Table
  final int TT_CAPACITY = 50000;
  LinkedHashMap<Long, Float> transTable = new LinkedHashMap<Long, Float>(TT_CAPACITY, 0.75f, true) {
    protected boolean removeEldestEntry(Map.Entry<Long, Float> eldest) {
      return size() > TT_CAPACITY;
    }
  };

  ChessEngine(Piece[][] board, int cols, int rows, String startTurn){
    this.board = board;
    this.cols = cols;
    this.rows = rows;
    this.turn = startTurn;
    this.selected = null;
    this.legal = new ArrayList<Cell>();
  }

  // Public API
  String getTurn(){ return turn; }
  Piece getSelected(){ return selected; }
  ArrayList<Cell> getLegal(){ return legal; }

  // this call when the UI detects a click on a board square
  String handleClick(int c, int r){
    if (!inBounds(c,r)) return "noop";

    Piece p = board[c][r];

    // No selection yet
    if (selected == null){
      if (p != null){
        if (p.side.equals(turn)){
          select(p);
          return "selected";
        } else {
          // clicked enemy with no selection results in preview in your UI (Optional)
          return "noop";
        }
      } else {
        // empty click with no selection
        return "noop";
      }
    }

    // Clicking the selected piece again results in deselect
    if (p == selected){
      clearSelection();
      return "deselected";
    }

    // Try to move to clicked square if it's legal
    if (isInLegal(c,r)){
      moveSelectedTo(c,r);
      clearSelection();
      swapTurn();
      return "moved";
    }

    // If you clicked another friendly piece, switch selection
    if (p != null && p.side.equals(turn)){
      select(p);
      return "selected";
    }

    // clicked empty or enemy not in legal squares results in keep selection
    return "noop";
  }

  // Recompute the legal moves for a piece that belongs to turn
  void select(Piece p){
    selected = p;
    legal = generateLegalMovesFiltered(p);
  }

  void clearSelection(){
    selected = null;
    legal.clear();
  }

  // idkdikdikddididkikdkddikdikikxs

  boolean inBounds(int c, int r){
    return c >= 0 && c < cols && r >= 0 && r < rows;
  }

  boolean isInLegal(int c, int r){
    for (Cell cell : legal) if (cell.c == c && cell.r == r) return true;
    return false;
  }

  void swapTurn(){ turn = turn.equals("ham") ? "tobis" : "ham"; }

  // Actually commit a move on the live board (now wiht promotion!)
  void moveSelectedTo(int tc, int tr){
    if (selected == null) return;
  
    // capture if any
    board[tc][tr] = selected;
    board[selected.col][selected.row] = null;
    selected.col = tc;
    selected.row = tr;
  
    // Automatically promote pawn when it reaches last rank or first
    maybePromote(selected);
  }


  // --- Move generation & check filtering --- (#######)

  ArrayList<Cell> generatePseudoMoves(Piece p){
    ArrayList<Cell> out = new ArrayList<Cell>();
    String side = p.side;

    if (p.type.equals("knight")){
      int[][] d = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
      for (int[] m : d){
        int nc = p.col + m[0], nr = p.row + m[1];
        if (inBounds(nc,nr) && (board[nc][nr] == null || !board[nc][nr].side.equals(side))){
          out.add(new Cell(nc,nr));
        }
      }
    }

    if (p.type.equals("bishop") || p.type.equals("queen")){
      slide(out, p,  1,  1);
      slide(out, p,  1, -1);
      slide(out, p, -1,  1);
      slide(out, p, -1, -1);
    }

    if (p.type.equals("rook") || p.type.equals("queen")){
      slide(out, p,  1,  0);
      slide(out, p, -1,  0);
      slide(out, p,  0,  1);
      slide(out, p,  0, -1);
    }

    if (p.type.equals("king")){
      int[][] d = {{1,1},{1,0},{1,-1},{0,1},{0,-1},{-1,1},{-1,0},{-1,-1}};
      for (int[] m : d){
        int nc = p.col + m[0], nr = p.row + m[1];
        if (inBounds(nc,nr) && (board[nc][nr] == null || !board[nc][nr].side.equals(side))){
          out.add(new Cell(nc,nr));
        }
      }
      // (Castling not implemented here) will do so later
    }

    if (p.type.equals("pawn")){
      int dir = side.equals("ham") ? -1 : 1;
      int startRow = side.equals("ham") ? rows - 2 : 1;

      // forward 1
      int f1c = p.col, f1r = p.row + dir;
      if (inBounds(f1c,f1r) && board[f1c][f1r] == null){
        out.add(new Cell(f1c,f1r));

        // forward 2 from start if clear
        int f2r = p.row + 2*dir;
        if (p.row == startRow && inBounds(f1c,f2r) && board[f1c][f2r] == null){
          out.add(new Cell(f1c,f2r));
        }
      }
      // captures
      for (int dc=-1; dc<=1; dc+=2){
        int nc = p.col + dc, nr = p.row + dir;
        if (inBounds(nc,nr) && board[nc][nr] != null && !board[nc][nr].side.equals(side)){
          out.add(new Cell(nc,nr));
        }
      }
      // (En passant not implemented) will do so later
    }

    return out;
  }

  void slide(ArrayList<Cell> out, Piece p, int dc, int dr){
    int nc = p.col + dc, nr = p.row + dr;
    while (inBounds(nc,nr)){
      if (board[nc][nr] == null){
        out.add(new Cell(nc,nr));
      } else {
        if (!board[nc][nr].side.equals(p.side)) out.add(new Cell(nc,nr));
        break;
      }
      nc += dc; nr += dr;
    }
  }

 // Filter pseudo legal moves by removing those that leave own king in check
ArrayList<Cell> generateLegalMovesFiltered(Piece p){
  ArrayList<Cell> raw = generatePseudoMoves(p);
  ArrayList<Cell> filtered = new ArrayList<Cell>();
  String side = p.side;

  // Find own king position once
  Cell kingPos = findKing(side);

  for (Cell mv : raw){
    Piece captured = board[mv.c][mv.r];
    int oc = p.col, or = p.row;

    // make (fast, no allocation)
    board[mv.c][mv.r] = p;
    board[oc][or] = null;
    p.col = mv.c; p.row = mv.r;

    boolean ok;
    if (p.type.equals("king")) {
      // ensure not moving into attack
      ok = !squareAttackedBy(mv.c, mv.r, opposite(side));
    } else {
      ok = (kingPos == null) ? true : !squareAttackedBy(kingPos.c, kingPos.r, opposite(side));
    }

    // undo move
    p.col = oc; p.row = or;
    board[oc][or] = p;
    board[mv.c][mv.r] = captured;

    if (ok) filtered.add(mv);
  }
  return filtered;
}

  boolean isKingInCheck(String side){
    Cell k = findKing(side);
    if (k == null) return false; // no king found equals treat as not in check
    return squareAttackedBy(k.c, k.r, opposite(side));
  }

  Cell findKing(String side){
    for (int c=0;c<cols;c++){
      for (int r=0;r<rows;r++){
        Piece p = board[c][r];
        if (p != null && p.side.equals(side) && p.type.equals("king")){
          return new Cell(c,r);
        }
      }
    }
    return null;
  }

  String opposite(String s){ return s.equals("ham") ? "tobis" : "ham"; }

  // if chosen tile is attacked
  boolean squareAttackedBy(int tc, int tr, String attackerSide){
    // Knights
    int[][] kn = {{2,1},{1,2},{-1,2},{-2,1},{-2,-1},{-1,-2},{1,-2},{2,-1}};
    for (int[] m : kn){
      int c = tc + m[0], r = tr + m[1];
      if (inBounds(c,r)){
        Piece p = board[c][r];
        if (p != null && p.side.equals(attackerSide) && p.type.equals("knight")) return true;
      }
    }
    // King (adjacent)
    int[][] kg = {{1,1},{1,0},{1,-1},{0,1},{0,-1},{-1,1},{-1,0},{-1,-1}};
    for (int[] m : kg){
      int c = tc + m[0], r = tr + m[1];
      if (inBounds(c,r)){
        Piece p = board[c][r];
        if (p != null && p.side.equals(attackerSide) && p.type.equals("king")) return true;
      }
    }
    // Sliding: rook/queen (orthogonal)
    if (rayHits(tc,tr, 1,0, attackerSide, "rook","queen")) return true;
    if (rayHits(tc,tr,-1,0, attackerSide, "rook","queen")) return true;
    if (rayHits(tc,tr, 0,1, attackerSide, "rook","queen")) return true;
    if (rayHits(tc,tr, 0,-1,attackerSide, "rook","queen")) return true;

    // Sliding: bishop/queen (diagonals)
    if (rayHits(tc,tr, 1,1, attackerSide, "bishop","queen")) return true;
    if (rayHits(tc,tr, 1,-1,attackerSide, "bishop","queen")) return true;
    if (rayHits(tc,tr,-1,1, attackerSide, "bishop","queen")) return true;
    if (rayHits(tc,tr,-1,-1,attackerSide, "bishop","queen")) return true;

    // Pawns (they attack forward-diagonal toward their movement)
    int dir = attackerSide.equals("ham") ? -1 : 1;
    int pr = tr - dir; // pawn that could attack [tc,tr] would be one step backward relative to its attack
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
    int c = tc + dc, r = tr + dr;
    while (inBounds(c,r)){
      Piece p = board[c][r];
      if (p != null){
        if (p.side.equals(side) && (p.type.equals(t1) || p.type.equals(t2))) return true;
        return false;
      }
      c += dc; r += dr;
    }
    return false;
  }

  // Simple checkmate/stalemate helpers (maybe remove stalemate in future)
  boolean noLegalMovesFor(String side){
    for (int c=0;c<cols;c++){
      for (int r=0;r<rows;r++){
        Piece p = board[c][r];
        if (p != null && p.side.equals(side)){
          if (generateLegalMovesFiltered(p).size() > 0) return false;
        }
      }
    }
    return true;
  }

  boolean isCheckmate(String side){
    return isKingInCheck(side) && noLegalMovesFor(side);
  }

  boolean isStalemate(String side){
    return !isKingInCheck(side) && noLegalMovesFor(side);
  }
  // WEIGHTS
  final float TEMPO_BONUS = 0.10f; // small nudge for side to move
  final float BISHOP_PAIR = 0.30f; // bishop pair bonus
  final float DOUBLED_PAWN = 0.18f;
  final float ISOLATED_PAWN = 0.18f;
  final float PASSED_PAWN  = 0.22f;
  
  // If quiescence made things slow/erratic early, slightly tighten it:
  final int QDEPTH_MAX_TUNED = 4;
  final int QCAPHARD_CAP_TUNED = 10;
  final int QEVASION_CAP_TUNED = 12;
  final float BAD_TRADE_MARGIN_TUNED = 0.5f;
  
  void tuneQParams(){
    // more stuff if used in future
    // QDEPTH_MAX = QDEPTH_MAX_TUNED;
    // QCAPHARD_CAP = QCAPHARD_CAP_TUNED;
    // QEVASION_CAP = QEVASION_CAP_TUNED;
    // BAD_TRADE_MARGIN = BAD_TRADE_MARGIN_TUNED;
  }
  
  
  float evaluate() {
    // uses the Zobrist cache which prevents redundant re-evaluation
    long key = zobristHash();
    Float cached = evalCache.get(key);
    if (cached != null) return cached;
  
    float matMid = 0, matEnd = 0;
    int phase = 0, phaseMax = 0;
    int hamBishops = 0, tobisBishops = 0;
    int hamKnightsDev = 0, tobisKnightsDev = 0;
    int hamBishopsDev = 0, tobisBishopsDev = 0;
  
    // pawn file counters
    int[] hamPawnsInFile = new int[cols];
    int[] tobisPawnsInFile = new int[cols];
  
    float cx = (cols - 1) * 0.5f, cy = (rows - 1) * 0.5f;
  
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        Piece p = board[c][r];
        if (p == null) continue;
  
        float base = pieceValue(p.type);
  
        // --- Phase tracking ---
        int ph = 0;
        if (p.type.equals("pawn")) ph = 0;
        else if (p.type.equals("knight") || p.type.equals("bishop")) ph = 1;
        else if (p.type.equals("rook")) ph = 2;
        else if (p.type.equals("queen")) ph = 4;
        phase += ph; phaseMax += 4;
  
        // --- Piece square contribution ---
        float psMid = psqtMid(p, c, r, cx, cy);
        float psEnd = psqtEnd(p, c, r, cx, cy);
  
        // --- Piece Development ---
        boolean onBack = (p.side.equals("tobis") ? r == 0 : r == rows - 1);
        if (p.type.equals("knight")) {
          if (!onBack) {
            if (p.side.equals("tobis")) tobisKnightsDev++; else hamKnightsDev++;
          }
        }
        if (p.type.equals("bishop")) {
          if (p.side.equals("tobis")) tobisBishops++; else hamBishops++;
          if (!onBack) {
            if (p.side.equals("tobis")) tobisBishopsDev++; else hamBishopsDev++;
          }
        }
  
        // --- Pawn structure counts ---
        // pawn together is better in chess
        if (p.type.equals("pawn")) {
          if (p.side.equals("tobis")) tobisPawnsInFile[c]++;
          else hamPawnsInFile[c]++;
        }
  
        // --- Material + PSQT accumulation ---
        float mid = base + psMid;
        float end = base + psEnd;
        if (p.side.equals("tobis")) { matMid += mid; matEnd += end; }
        else { matMid -= mid; matEnd -= end; }
      }
    }
  
    // bishop pair bonuses ---
    if (tobisBishops >= 2) { matMid += BISHOP_PAIR; matEnd += BISHOP_PAIR; }
    if (hamBishops >= 2) { matMid -= BISHOP_PAIR; matEnd -= BISHOP_PAIR; }
  
    // phase blending ---
    float phaseBlend = clamp01(phase / max(1f, (float) phaseMax));
    float openingWeight = phaseBlend;
    float endgameWeight = 1f - openingWeight;
  
    // development incentives ---
    matMid += openingWeight * ((tobisKnightsDev + tobisBishopsDev)
                             - (hamKnightsDev + hamBishopsDev)) * 0.06f;
  
    // early queen penalty ---
    matMid += openingWeight * earlyQueenPenalty("tobis");
    matMid -= openingWeight * earlyQueenPenalty("ham");
  
    // central pawn freedom ---
    matMid += openingWeight * centerPawnNudge("tobis");
    matMid -= openingWeight * centerPawnNudge("ham");
  
    // pawn structure ---
    float strTobis = pawnStructureScore(tobisPawnsInFile, "tobis");
    float strHam   = pawnStructureScore(hamPawnsInFile, "ham");
    matMid += strTobis - strHam;
    matEnd += (strTobis - strHam) * 0.8f;
  
    // knight Centralization Bonus ---
    float knightCentral = knightCenterBonus("tobis") - knightCenterBonus("ham");
    matMid += openingWeight * knightCentral * 0.8f; // strong in opening
  
    // center Pawn Push Bonus ---
    float pawnPush = centralPawnAdvanceBonus("tobis") - centralPawnAdvanceBonus("ham");
    matMid += openingWeight * pawnPush * 1.0f;
  
    // tempo bonus ---
    if (turn.equals("tobis")) matMid += TEMPO_BONUS * openingWeight;
    else matMid -= TEMPO_BONUS * openingWeight;
  
    // final blended score ---
    float score = openingWeight * matMid + endgameWeight * matEnd;
  
    // Cache and return
    evalCache.put(key, score);
    return score;
  }
  
  // move ordering helper
  ArrayList<Cell> orderedMoves(Piece p) {
    ArrayList<Cell> moves = generateLegalMovesFiltered(p);
    final String side = p.side;
    final boolean opening = isOpeningPhase();
  
    moves.sort(new Comparator<Cell>() {
      public int compare(Cell a, Cell b) {
        int sa = moveScore(p, a, side, opening);
        int sb = moveScore(p, b, side, opening);
        return Integer.compare(sb, sa); // high to low
      }
    });
    return moves;
  }
  
  // Bonus for knights being near center squares
  float knightCenterBonus(String side){
    float bonus = 0;
    float cx = (cols - 1) * 0.5f, cy = (rows - 1) * 0.5f;
    for (int c = 0; c < cols; c++){
      for (int r = 0; r < rows; r++){
        Piece p = board[c][r];
        if (p == null || !p.side.equals(side) || !p.type.equals("knight")) continue;
        float dc = c - cx; if (dc < 0) dc = -dc;
        float dr = r - cy; if (dr < 0) dr = -dr;
        float dist = dc + dr;
  
        bonus += max(0, 4f - dist) * 0.08f; // closer to center means higher bonus
      }
    }
    return bonus;
  }
  
  // Bonus for advancing center pawns
  float centralPawnAdvanceBonus(String side){
    float bonus = 0;
    int dFile = (cols % 2 == 0) ? cols / 2 - 1 : cols / 2;
    int eFile = cols / 2;
    for (int c = 0; c < cols; c++){
      if (c != dFile && c != eFile) continue;
      for (int r = 0; r < rows; r++){
        Piece p = board[c][r];
        if (p == null || !p.side.equals(side) || !p.type.equals("pawn")) continue;
        float progress = (side.equals("tobis") ? r : (rows - 1 - r)) / (float)(rows - 1);
        bonus += progress * 0.25f; // reward for pushing d/e pawns up
      }
    }
    return bonus;
  }
  
  
  boolean isOpeningPhase(){
    int material = 0;
    for (int c=0;c<cols;c++) for (int r=0;r<rows;r++){
      Piece q = board[c][r];
      if (q==null) continue;
      if (q.type.equals("queen")) material += 4;
      else if (q.type.equals("rook")) material += 2;
      else if (q.type.equals("knight") || q.type.equals("bishop")) material += 1;
    }
    // larger number equals more opening; tune threshold for board size (VERY IMPORTANT) DONT FORGET!!!
    return material > (cols >= 10 ? 28 : 20);
  }
  
  // Board size adaptive move scoring
  int moveScore(Piece p, Cell mv, String side, boolean opening) {
    int score = 0;
    Piece target = board[mv.c][mv.r];
  
    //MVV-LVA
    if (target != null) {
      int victim = round(pieceValue(target.type) * 100);
      int attacker = round(pieceValue(p.type) * 100);
      score += (victim * 10 - attacker);
    }
  
    // --- Earlygame ---
    if (opening) {
      int back = side.equals("tobis") ? 0 : rows - 1;
      int startRow = side.equals("tobis") ? 1 : rows - 2;
      float cx = (cols - 1) * 0.5f, cy = (rows - 1) * 0.5f;
  
      int eFile = round(cx); // central file which adjust based on board size
      int dFile = (cols % 2 == 0) ? eFile - 1 : eFile;
      int center1 = eFile;
      int center2 = (cols % 2 == 0) ? eFile - 1 : eFile;
  
      // 1) Develop minors off the back rank
      if ((p.type.equals("knight") || p.type.equals("bishop")) && p.row == back && mv.r != back)
        score += 80;
  
      // central file / rank control
      float distC = abs(mv.c - cx);
      float distR = abs(mv.r - cy);
      float maxCenterDist = max(cols, rows) * 0.5f;
      score += max(0, (maxCenterDist - (distC + distR))) * 4;
  
      // early central pawn pushes
      if (p.type.equals("pawn") && p.row == startRow && (p.col == dFile || p.col == eFile))
        score += 90; // strong priority
  
      // discourage early queen development
      if (p.type.equals("queen") && p.row == back && mv.r != back)
        score -= 90;
  
      // minor pieces moving away from center
      if (target == null && (p.type.equals("knight") || p.type.equals("bishop"))) {
        float fromC = abs(p.col - cx) + abs(p.row - cy);
        float toC   = abs(mv.c - cx) + abs(mv.r - cy);
        if (toC > fromC + 0.1f) score -= 20;
      }
  
      // rooks prefer central files
      if (p.type.equals("rook")) {
        float distFromCenter = abs(mv.c - cx);
        score += max(0, (cols * 0.5f - distFromCenter)) * 2;
        if (p.row == back && mv.r != back) score += 10;
      }
  
      // pawn forward bonus
      if (p.type.equals("pawn") && abs(mv.r - p.row) == 1)
        score += 10;
  
      if (p.type.equals("pawn")) {
        float normPos = p.col / (float)(cols - 1);
        float distFromCenterNorm = abs(normPos - 0.5f) * 2;
        
        if (distFromCenterNorm > 0.8f) score -= 80; // true edge
        else if (distFromCenterNorm > 0.6f) score -= 40; // near edge
      }
    }
  
    // --- Midgame / Endgame ---
    else {
      // encourage passed pawn races and flank expansion later
      if (p.type.equals("pawn")) {
        float normCol = p.col / (float)(cols - 1);
        float distEdge = min(normCol, 1 - normCol);
        if (distEdge < 0.15f) score += 20; // encourage edge pawns only late
      }
    }
  
    return score;
  }
  
  
  float quiescence(String side, float alpha, float beta, int qDepth) {
    float stand = evaluate(); // tobis positive
  
    if (side.equals("tobis")) {
      if (stand >= beta) return stand; 
      if (stand > alpha) alpha = stand; 
    } else {
      if (stand <= alpha) return stand; 
      if (stand < beta) beta = stand; 
    }
  
    // depth cap for safety since freezing is bad
    if (qDepth >= QDEPTH_MAX) return side.equals("tobis") ? alpha : beta;
  
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
  
    // capture-only search
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
        if (alpha >= beta) return side.equals("tobis") ? alpha : beta; // cutoff point
      }
    }
  
    return side.equals("tobis") ? alpha : beta;
  }
  
  
  // Actual chess engine
  float minimax(String side, int depth, float alpha, float beta) {
    if (depth == 0) return quiescence(side, alpha, beta, 0);
  
    boolean maximizing = side.equals("tobis");
    float best = maximizing ? -1e9f : 1e9f;
  
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        Piece p = board[c][r];
        if (p == null || !p.side.equals(side)) continue;
  
        ArrayList<Cell> moves = orderedMoves(p);
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
  
  
  // Copy of a board state for AI search
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
    float dist = dx + dy;                // Manhattan distance to center
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
  
  // Endgame PSQT
  // centralize king, push passed pawns; other pieces modestly central
  float psqtEnd(Piece p, int c, int r, float cx, float cy){
    float dx = abs(c - cx), dy = abs(r - cy);
    float center = (5f - (dx + dy)) * 0.06f;
  
    if (p.type.equals("king")) return center * 2.0f; // king wants to be active
    if (p.type.equals("pawn")) return ((p.side.equals("tobis") ? r : (rows - 1 - r)) * 0.06f);
    if (p.type.equals("rook")) return 0.04f * mobilityCheap(p);
    if (p.type.equals("queen"))return 0.03f * mobilityCheap(p);
    return center * 0.6f;
  }
  
  int mobilityCheap(Piece p){
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
  
  // Open/semi open file bonus for rooks
  int openFileBonus(Piece p, int file){
    if (!p.type.equals("rook")) return 0;
    boolean myPawn = false, oppPawn = false;
    for (int r=0; r<rows; r++){
      Piece q = board[file][r];
      if (q != null && q.type.equals("pawn")){
        if (q.side.equals(p.side)) myPawn = true; else oppPawn = true;
      }
    }
    if (!myPawn && !oppPawn) return 2; // open
    if (!myPawn && oppPawn)   return 1; // semi-open
    return 0;
  }
  
  // Early queen penalty if <2 minors developed and queen left back rank
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
  
  // Encourage freeing center pawns
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
  
  // pawn structure over all files
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
    // scan all the pawns, if any opposing pawn is on same/adjacent file , not passed
    for (int c = max(0, f-1); c <= min(cols-1, f+1); c++){
      for (int r=0; r<rows; r++){
        Piece q = board[c][r];
        if (q == null || !q.type.equals("pawn")) continue;
        if (side.equals(q.side)) continue;
        // ahead relative to 'side'
        if ( (side.equals("tobis") && r >= 0) || (side.equals("ham") && r <= rows-1) ){
          //  ensure there exists a friendly pawn ahead
        }
      }
    }
    for (int c = max(0, f-1); c <= min(cols-1, f+1); c++){
      for (int r=0; r<rows; r++){
        Piece q = board[c][r];
        if (q == null || !q.type.equals("pawn") || side.equals(q.side)) continue;
        if (side.equals("tobis")) {
          return false;
        } else {
          return false;
        }
      }
    }
    return true; // very light heuristic
  }
  
  void maybePromote(Piece p) {
    if (p == null || !p.type.equals("pawn")) return;
  
    int lastRowHam = 0; // top of board for ham pawns
    int lastRowTobis = rows - 1;  // bottom of board for tobis pawns
  
    boolean shouldPromote = 
      (p.side.equals("ham")   && p.row == lastRowHam) ||
      (p.side.equals("tobis") && p.row == lastRowTobis);
  
    if (shouldPromote) {
      p.type = "queen";
      p.img = p.side.equals("ham") ? hamQueenImg : tobisQueenImg;
      p.scaleFactor = 2;
    }
  }
  
  // Fast Zobrist hash for position caching
  long zobristHash() {
    long h = 1469598103934665603L;
    for (int c=0;c<cols;c++) for (int r=0;r<rows;r++) {
      Piece p = board[c][r];
      if (p==null) continue;
      h ^= (p.side.hashCode()*31L + p.type.hashCode()*17L + c*7L + r);
      h *= 1099511628211L;
    }
    h ^= turn.hashCode();
    return h;
  }
}
