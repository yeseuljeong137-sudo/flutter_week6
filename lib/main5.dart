import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const LandGameApp());
}

class LandGameApp extends StatelessWidget {
  const LandGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '플러터 고속 AI 땅따먹기 (main5)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LandGameScreen(),
    );
  }
}

class LandGameScreen extends StatefulWidget {
  const LandGameScreen({super.key});

  @override
  State<LandGameScreen> createState() => _LandGameScreenState();
}

class _LandGameScreenState extends State<LandGameScreen> {
  static const int gridSize = 10; // 10x10 보드판
  
  // 0: 빈 땅, 1: 플레이어, 2: AI
  List<List<int>> _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
  
  bool _isPlaying = false;
  bool _isAiThinking = false;
  String _gameStatus = "버튼을 누르면 30초 폭풍 대전이 시작됩니다!";
  
  int _playerCount = 0;
  int _aiCount = 0;

  // [Stream] 시간 및 실시간 스코어 중계 스트림
  final StreamController<Map<String, dynamic>> _gameStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _countdownTimer; // 1초 주기 타이머
  Timer? _aiAttackTimer;  // 0.2초 주기 고속 AI 타이머
  int _timeLeft = 30;

  @override
  void initState() {
    super.initState();
    _calculateScores();
  }

  void _calculateScores() {
    int p = 0;
    int a = 0;
    for (var r in _grid) {
      for (var cell in r) {
        if (cell == 1) p++;
        if (cell == 2) a++;
      }
    }
    _playerCount = p;
    _aiCount = a;
    
    if (!_gameStreamController.isClosed) {
      _gameStreamController.add({
        'timeLeft': _timeLeft,
        'playerScore': _playerCount,
        'aiScore': _aiCount,
      });
    }
  }

  void _startGame() {
    _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _timeLeft = 30;
    _isPlaying = true;
    _isAiThinking = false;
    _gameStatus = "⚔️ 폭풍 전투 중! 빈 땅이나 AI 땅을 빠르게 터치하세요!";
    _calculateScores();

    _countdownTimer?.cancel();
    _aiAttackTimer?.cancel();

    // 1. 시간 차감 타이머 (1초 주기)
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0 && _isPlaying) {
        _timeLeft--;
        _calculateScores();
      } else {
        _endGame();
      }
    });

    // 2. ⚡ AI 초고속 공격 타이머 (0.2초마다 실행)
    _aiAttackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (_isPlaying) {
        _triggerAiTurn();
      }
    });
  }

  void _endGame() {
    _isPlaying = false;
    _countdownTimer?.cancel();
    _aiAttackTimer?.cancel();
    _calculateScores();

    setState(() {
      if (_playerCount > _aiCount) {
        _gameStatus = "🏆 대박! AI를 꺾고 승리하셨습니다!";
      } else if (_aiCount > _playerCount) {
        _gameStatus = "💻 AI가 영토를 점령했습니다! 다시 도전하세요!";
      } else {
        _gameStatus = "🤝 완벽한 호각세! 무승부입니다!";
      }
    });
  }

  void _onTapCell(int row, int col) {
    if (!_isPlaying || _grid[row][col] == 1) return;

    setState(() {
      _grid[row][col] = 1; // 내 땅 점령 (상대 땅 뺏기 가능)
    });
    _calculateScores();
  }

  // ==========================================
  // [Isolate & async/await] 고속 비동기 연산
  // ==========================================
  Future<void> _triggerAiTurn() async {
    if (!_isPlaying || _isAiThinking) return;
    _isAiThinking = true;

    List<int> aiTarget;

    if (kIsWeb) {
      // 🌐 웹: 메인스레드 가벼운 최적화 연산
      await Future.delayed(Duration.zero);
      aiTarget = _findAiStrategicCell(_grid);
    } else {
      // 🪟 Windows: 고속 Isolate 연산
      List<List<int>> gridCopy = List.generate(gridSize, (r) => List.from(_grid[r]));
      aiTarget = await compute(_findAiStrategicCellIsolate, gridCopy);
    }

    int targetRow = aiTarget[0];
    int targetCol = aiTarget[1];

    if (targetRow != -1 && targetCol != -1 && _isPlaying) {
      setState(() {
        _grid[targetRow][targetCol] = 2; // AI 땅 점령
      });
      _calculateScores();
    }
    _isAiThinking = false;
  }

  static List<int> _findAiStrategicCellIsolate(List<List<int>> grid) {
    return _findAiStrategicCell(grid);
  }

  // 🤖 AI 영토 확장 전략 알고리즘 (인접 영토 공격 가중치 부여)
  static List<int> _findAiStrategicCell(List<List<int>> grid) {
    List<List<int>> highPriority = []; // AI 땅 주변 (확장)
    List<List<int>> normalPriority = []; // 빈 공간 또는 플레이어 공간

    int size = grid.length;
    List<int> dr = [-1, 1, 0, 0];
    List<int> dc = [0, 0, -1, 1];

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (grid[r][c] != 2) {
          // AI 땅이 아닌 곳 중에서, 상하좌우에 AI 땅(2)이 있는지 검사
          bool hasAiNeighbor = false;
          for (int i = 0; i < 4; i++) {
            int nr = r + dr[i];
            int nc = c + dc[i];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              if (grid[nr][nc] == 2) {
                hasAiNeighbor = true;
                break;
              }
            }
          }

          if (hasAiNeighbor) {
            highPriority.add([r, c]); // 인접 영토 최고 우선순위
          } else {
            normalPriority.add([r, c]);
          }
        }
      }
    }

    final random = Random();
    // 80% 확률로 인접 땅을 확장하고, 20% 확률로 무작위 게릴라 침투를 보냅니다.
    if (highPriority.isNotEmpty && random.nextDouble() < 0.8) {
      return highPriority[random.nextInt(highPriority.length)];
    } else if (normalPriority.isNotEmpty) {
      return normalPriority[random.nextInt(normalPriority.length)];
    }
    
    return [-1, -1];
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _aiAttackTimer?.cancel();
    _gameStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double boardWidth = MediaQuery.of(context).size.shortestSide * 0.85;
    if (boardWidth > 450) boardWidth = 450;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ AI 초고속 땅따먹기'),
        backgroundColor: Colors.indigo.shade100,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StreamBuilder<Map<String, dynamic>>(
                stream: _gameStreamController.stream,
                initialData: const {'timeLeft': 30, 'playerScore': 0, 'aiScore': 0},
                builder: (context, snapshot) {
                  final data = snapshot.data!;
                  return Card(
                    elevation: 4,
                    color: Colors.indigo.shade50,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text("🔵 나의 영토", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${data['playerScore']}칸", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text("⏱️ 남은 시간", style: TextStyle(color: Colors.grey)),
                              Text("${data['timeLeft']}초", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: data['timeLeft'] <= 10 ? Colors.red : Colors.black)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text("🔴 AI 영토", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${data['aiScore']}칸", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _gameStatus,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 15),
              Container(
                width: boardWidth,
                height: boardWidth,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gridSize * gridSize,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSize,
                  ),
                  itemBuilder: (context, index) {
                    int row = index ~/ gridSize;
                    int col = index % gridSize;
                    int cellValue = _grid[row][col];

                    Color cellColor = Colors.grey.shade100;
                    if (cellValue == 1) cellColor = Colors.blue.shade400;
                    if (cellValue == 2) cellColor = Colors.red.shade400;

                    return GestureDetector(
                      onTapDown: (_) => _onTapCell(row, col), // 초고속 입력을 위해 터치 누르는 순간 즉시 반영
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 50), // 변화 연출 고속화
                        margin: const EdgeInsets.all(1.5),
decoration: BoxDecoration(
color: cellColor,
borderRadius: BorderRadius.circular(2),
border: Border.all(
color: Colors.black.withOpacity(0.12),
width: 0.5,
),
),
),
);
},
),
),
const SizedBox(height: 25),
ElevatedButton.icon(
onPressed: _isPlaying ? null : _startGame,
icon: Icon(_isPlaying ? Icons.flash_on : Icons.play_arrow),
label: Text(_isPlaying ? "광속 대전 중!!" : "게임 시작 (광속 모드)"),
style: ElevatedButton.styleFrom(
backgroundColor: Colors.indigo.shade200,
foregroundColor: Colors.black87,
padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
),
),
],
),
),
),
);
}
}