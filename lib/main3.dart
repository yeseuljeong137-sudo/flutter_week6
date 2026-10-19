import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

void main() {
  runApp(const OmokApp());
}

class OmokApp extends StatelessWidget {
  const OmokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '플러터 AI 오목 (main3)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const OmokGameScreen(),
    );
  }
}

class OmokGameScreen extends StatefulWidget {
  const OmokGameScreen({super.key});

  @override
  State<OmokGameScreen> createState() => _OmokGameScreenState();
}

class _OmokGameScreenState extends State<OmokGameScreen> {
  static const int boardSize = 15; // 오목 표준 15x15 판
  
  // 0: 빈칸, 1: 흑돌 (플레이어), 2: 백돌 (AI)
  List<List<int>> _board = List.generate(boardSize, (_) => List.filled(boardSize, 0));
  
  bool _isPlayerTurn = true; // 현재 플레이어(흑) 차례인지 여부
  bool _isAiThinking = false; // AI 연산 중 상태 표시
  String _gameStatus = "당신의 차례입니다 (흑돌)";
  bool _gameOver = false;

  // 1. [Stream] 대국 진행 시간 표시를 위한 타이머 스트림
  final StreamController<int> _timerController = StreamController<int>();
  Timer? _gameTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimerStream();
  }

  // ==========================================
  // [개념 1] Stream: 대국 시간 카운트 작동
  // ==========================================
  void _startTimerStream() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_gameOver && !_timerController.isClosed) {
        _elapsedSeconds++;
        _timerController.add(_elapsedSeconds);
      }
    });
  }

  // 게임 재시작 함수
  void _resetGame() {
    setState(() {
      _board = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      _isPlayerTurn = true;
      _isAiThinking = false;
      _gameStatus = "당신의 차례입니다 (흑돌)";
      _gameOver = false;
      _elapsedSeconds = 0;
    });
    _timerController.add(0);
  }

  // 플레이어가 바둑판을 클릭했을 때 (async/await)
  void _onTapBoard(int row, int col) async {
    if (_gameOver || !_isPlayerTurn || _isAiThinking || _board[row][col] != 0) return;

    // 1. 플레이어 착수
    setState(() {
      _board[row][col] = 1; // 흑돌 놓기
    });

    // 승리 판정
    if (_checkWinner(row, col, 1)) {
      setState(() {
        _gameStatus = "🎉 축하합니다! 당신이 승리했습니다!";
        _gameOver = true;
      });
      return;
    }

    // 2. AI 턴으로 전환 (async/await 및 Isolate 연산 유도)
    setState(() {
      _isPlayerTurn = false;
      _gameStatus = "🤖 AI가 최적의 수를 생각하는 중...";
    });

    // AI 착수 로직 실행
    await _runAiTurn();
  }

  // ==========================================
  // [개념 2, 3] async/await & Isolate 최적 배치 연산
  // ==========================================
  Future<void> _runAiTurn() async {
    setState(() => _isAiThinking = true);

    Map<String, int> aiMove;

    if (kIsWeb) {
      // 🌐 웹 환경: Isolate 우회용 비동기 딜레이 후 연산
      await Future.delayed(const Duration(milliseconds: 600));
      aiMove = _findBestMove(_board);
    } else {
      // 🪟 Windows 네이티브 환경: 완전한 멀티 스레드 Isolate 가동
      List<List<int>> boardCopy = List.generate(boardSize, (r) => List.from(_board[r]));
      aiMove = await compute(_findBestMoveIsolate, boardCopy);
    }

    int aiRow = aiMove['row']!;
    int aiCol = aiMove['col']!;

    if (aiRow != -1 && aiCol != -1) {
      setState(() {
        _board[aiRow][aiCol] = 2; // 백돌 놓기
        _isAiThinking = false;
      });

      if (_checkWinner(aiRow, aiCol, 2)) {
        setState(() {
          _gameStatus = "💻 AI가 승리했습니다. 다시 도전해 보세요!";
          _gameOver = true;
        });
        return;
      }

      setState(() {
        _isPlayerTurn = true;
        _gameStatus = "당신의 차례입니다 (흑돌)";
      });
    } else {
      setState(() {
        _gameStatus = "무승부입니다!";
        _gameOver = true;
        _isAiThinking = false;
      });
    }
  }

  // Isolate를 위한 탑레벨/스테틱 전용 함수
  static Map<String, int> _findBestMoveIsolate(List<List<int>> board) {
    return _findBestMove(board);
  }

  // AI 가중치 기반 탐색 알고리즘
  static Map<String, int> _findBestMove(List<List<int>> board) {
    int bestScore = -1;
    int bestRow = -1;
    int bestCol = -1;

    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == 0) {
          int score = _evaluateCell(board, r, c);
          if (score > bestScore) {
            bestScore = score;
            bestRow = r;
            bestCol = c;
          }
        }
      }
    }

    if (bestRow == -1) {
      for (int r = 0; r < boardSize; r++) {
        for (int c = 0; c < boardSize; c++) {
          if (board[r][c] == 0) return {'row': r, 'col': c};
        }
      }
    }

    return {'row': bestRow, 'col': bestCol};
  }

  // 각 빈칸의 방어/공격 가중치 계산기
  static int _evaluateCell(List<List<int>> board, int r, int c) {
    int score = 0;
    // 🛠️ 오류 수정 완료: 방향 값 벡터 삽입 (정상 작동)
    List<int> dr = [0, 1, 1, 1];
    List<int> dc = [1, 0, 1, -1];

    for (int i = 0; i < 4; i++) {
      int playerCount = 0;
      int aiCount = 0;

      for (int step = -4; step <= 4; step++) {
        if (step == 0) continue;
        int nr = r + dr[i] * step;
        int nc = c + dc[i] * step;

        if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize) {
          if (board[nr][nc] == 1) playerCount++;
          if (board[nr][nc] == 2) aiCount++;
        }
      }
      if (playerCount == 4) score += 10000;
      if (aiCount == 4) score += 50000;
      if (playerCount == 3) score += 1000;
      if (aiCount == 3) score += 2000;
      score += playerCount + aiCount;
    }
    return score;
  }

  // 승리 판정 알고리즘
  bool _checkWinner(int r, int c, int player) {
    // 🛠️ 오류 수정 완료: 방향 값 벡터 삽입 (정상 작동)
    List<int> dr = [0, 1, 1, 1];
    List<int> dc = [1, 0, 1, -1];

    for (int i = 0; i < 4; i++) {
      int count = 1;

      int nr = r + dr[i];
      int nc = c + dc[i];
      while (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize && _board[nr][nc] == player) {
        count++;
        nr += dr[i];
        nc += dc[i];
      }

      nr = r - dr[i];
      nc = c - dc[i];
      while (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize && _board[nr][nc] == player) {
        count++;
        nr -= dr[i];
        nc -= dc[i];
      }

      if (count >= 5) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _timerController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double boardWidth = MediaQuery.of(context).size.shortestSide * 0.85;
    if (boardWidth > 500) boardWidth = 500;

    return Scaffold(
      appBar: AppBar(
        title: const Text('💡 AI 비동기 오목 (main3.dart)'),
        backgroundColor: Colors.amber.shade200,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
            tooltip: "게임 초기화",
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<int>(
                stream: _timerController.stream,
                initialData: 0,
                builder: (context, snapshot) {
                  final seconds = snapshot.data ?? 0;
                  final min = (seconds / 60).floor().toString().padLeft(2, '0');
                  final sec = (seconds % 60).toString().padLeft(2, '0');
                  return Text(
                    "⏱️ 진행 시간: $min:$sec",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _gameStatus,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _gameOver ? Colors.red : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: boardWidth,
                height: boardWidth,
                color: const Color(0xFFDCB35C),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: boardSize * boardSize,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: boardSize,
                  ),
                  itemBuilder: (context, index) {
                    int row = index ~/ boardSize;
                    int col = index % boardSize;
                    int cellValue = _board[row][col];

                    return GestureDetector(
                      onTap: () => _onTapBoard(row, col),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black.withOpacity(0.24), width: 0.5),
                        ),
                        child: Center(
                          child: cellValue == 0
                              ? null
                              : Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cellValue == 1 ? Colors.black : Colors.white,
                                    boxShadow: const [
BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))
],
),
),
),
),
);
},
),
),
const SizedBox(height: 25),
ElevatedButton.icon(
onPressed: _resetGame,
icon: const Icon(Icons.play_arrow),
label: const Text("처음부터 다시 하기"),
style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade100),
),
],
),
),
),
);
}
} 