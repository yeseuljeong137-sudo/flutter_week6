import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const OmokApp());
}

class OmokApp extends StatelessWidget {
  const OmokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '플러터 2인용 오목 (main6)',
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
  
  // 0: 빈칸, 1: 흑돌 (플레이어 1), 2: 백돌 (플레이어 2)
  List<List<int>> _board = List.generate(boardSize, (_) => List.filled(boardSize, 0));
  
  bool _isPlayer1Turn = true; // true면 흑돌(P1) 차례, false면 백돌(P2) 차례
  String _gameStatus = "⚫ 플레이어 1 (흑돌) 차례입니다";
  bool _gameOver = false;

  // [Stream] 대국 진행 시간 표시를 위한 타이머 스트림
  final StreamController<int> _timerController = StreamController<int>.broadcast();
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
      _isPlayer1Turn = true;
      _gameStatus = "⚫ 플레이어 1 (흑돌) 차례입니다";
      _gameOver = false;
      _elapsedSeconds = 0;
    });
    if (!_timerController.isClosed) {
      _timerController.add(0);
    }
  }

  // 바둑판을 클릭했을 때 (번갈아 가며 착수)
  void _onTapBoard(int row, int col) {
    if (_gameOver || _board[row][col] != 0) return;

    int currentStone = _isPlayer1Turn ? 1 : 2;

    setState(() {
      _board[row][col] = currentStone; // 해당 자리에 돌 놓기
    });

    // 승리 판정 (현재 동기화된 보드와 방금 착수한 행/열 기준)
    if (_checkWinner(row, col, currentStone)) {
      setState(() {
        _gameStatus = _isPlayer1Turn 
            ? "🎉 플레이어 1 (흑돌) 승리! 축하합니다!" 
            : "🎉 플레이어 2 (백돌) 승리! 축하합니다!";
        _gameOver = true;
      });
      return;
    }

    // 턴 교대
    setState(() {
      _isPlayer1Turn = !_isPlayer1Turn;
      _gameStatus = _isPlayer1Turn 
          ? "⚫ 플레이어 1 (흑돌) 차례입니다" 
          : "⚪ 플레이어 2 (백돌) 차례입니다";
    });
  }

  // 승리 판정 알고리즘
  bool _checkWinner(int r, int c, int player) {
    final List<int> dr = [0, 1, 1, -1];
    final List<int> dc = [1, 0, 1, -1];

    for (int i = 0; i < 4; i++) {
      int count = 1;

      // 정방향 탐색
      int nr = r + dr[i];
      int nc = c + dc[i];
      while (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize && _board[nr][nc] == player) {
        count++;
        nr += dr[i];
        nc += dc[i];
      }

      // 역방향 탐색
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
        title: const Text('⚔️ 오목 2인 대전 모드 (main6.dart)'),
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
              // 타이머 영역
              StreamBuilder<int>(
                stream: _timerController.stream,
                initialData: 0,
                builder: (context, snapshot) {
                  final seconds = snapshot.data ?? 0;
                  final min = (seconds / 60).floor().toString().padLeft(2, '0');
                  final sec = (seconds % 60).toString().padLeft(2, '0');
                  return Text(
                    "⏱️ 대국 시간: $min:$sec",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 10),
              
              // 턴 지시 전광판
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
                    color: _gameOver ? Colors.green.shade700 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 바둑판 영역
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
                label: const Text("판 새로고침 (다시 하기)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
