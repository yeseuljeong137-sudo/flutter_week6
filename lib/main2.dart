import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const NoticeApp());
}

class NoticeApp extends StatelessWidget {
  const NoticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '공지사항 앱',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const NoticeHomeScreen(),
    );
  }
}

class NoticeHomeScreen extends StatefulWidget {
  const NoticeHomeScreen({super.key});

  @override
  State<NoticeHomeScreen> createState() => _NoticeHomeScreenState();
}

class _NoticeHomeScreenState extends State<NoticeHomeScreen> {
  // 1. [Stream] 실시간 긴급 공지 제어를 위한 스트림 컨트롤러
  final StreamController<String> _urgentNoticeController = StreamController<String>();
  Timer? _timer;

  // 2. [async/await] 일반 공지사항 데이터 관리를 위한 상태 변수
  List<String> _notices = [];
  bool _isLoading = true;

  // 3. [Isolate] 연산 결과 저장용 변수
  String _isolateResult = "대기 중";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchNotices(); // async/await 실행
    _startUrgentNoticeStream(); // Stream 실행
  }

  // ==========================================
  // [개념 1] async / await: 서버 공지사항 로딩 구현
  // ==========================================
  Future<void> _fetchNotices() async {
    setState(() => _isLoading = true);
    
    // 가상의 네트워크 딜레이 1.5초
    await Future.delayed(const Duration(milliseconds: 1500));
    
    setState(() {
      _notices = [
        "[안내] 시스템 정기 점검 안내 (02/25)",
        "[이벤트] 바이브 코딩 챌린지 오픈!",
        "[필독] 개인정보 처리방침 개정 고지",
        "[업데이트] Windows 및 Web 크로스플랫폼 패치 완료",
      ];
      _isLoading = false;
    });
  }

  // ==========================================
  // [개념 2] Stream: 3초마다 바뀌는 실시간 긴급 공지
  // ==========================================
  void _startUrgentNoticeStream() {
    final List<String> urgentMessages = [
      "🚨 [긴급] 서버 일시적 부하 발생 - 순차 복구 중",
      "🔥 [알림] 금일 마감되는 공지사항을 확인하세요",
      "📢 [안내] 크롬 및 윈도우 완벽 호환 모드 실행 중",
    ];
    int index = 0;

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_urgentNoticeController.isClosed) {
        _urgentNoticeController.add(urgentMessages[index % urgentMessages.length]);
        index++;
      }
    });
  }

  // ==========================================
  // [개념 3] Isolate (with 크롬 가드): 무거운 공지 데이터 연산
  // ==========================================
  // Isolate 내부에서 실행될 최상위(또는 static) 함수 (Isolate는 독립된 메모리를 써야 하므로 밖에 있어야 함)
  static int _heavyCalculation(int count) {
    int total = 0;
    for (int i = 0; i < count; i++) {
      total += i;
    }
    return total;
  }

  Future<void> _runHeavyTask() async {
    setState(() {
      _isProcessing = true;
      _isolateResult = "연산 중...";
    });

    if (kIsWeb) {
      // 🌐 [크롬 웹 환경]: 크롬은 멀티 Isolate가 안 되므로 비동기 계산(Future)으로 우회하여 먹통 방지
      await Future.delayed(const Duration(milliseconds: 100)); // UI 갱신 유도
      int result = _heavyCalculation(50000000); // 연산 진행
      setState(() {
        _isolateResult = "Web(비동기) 결과: $result";
        _isProcessing = false;
      });
    } else {
      // 🪟 [Windows 앱 환경]: 완전히 독립된 백그라운드 스레드(Isolate) 가동
      // compute 함수는 Flutter 내부에서 Isolate.spawn을 쓰기 편하게 래핑해둔 필수 API입니다.
      int result = await compute(_heavyCalculation, 50000000);
      setState(() {
        _isolateResult = "Windows(Isolate) 결과: $result";
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _urgentNoticeController.close();
    super.dispose();
  }

  // UI 레이아웃 구성
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('종합 공지사항 보드'),
        backgroundColor: Colors.indigo.shade100,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 실시간 스트림 영역
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: StreamBuilder<String>(
                  stream: _urgentNoticeController.stream,
                  initialData: "📢 실시간 공지를 불러오는 중...",
                  builder: (context, snapshot) {
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            snapshot.data ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Isolate/무거운 연산 영역
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("⚙️ 환경별 무거운 작업 처리 (Isolate 테스트)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _isProcessing ? null : _runHeavyTask,
                          child: const Text("공지 데이터 무거운 연산 시작"),
                        ),
                        Text(_isolateResult, style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text("📋 일반 공지사항", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            // 3. async/await 일반 리스트 영역
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchNotices,
                      child: ListView.builder(
                        itemCount: _notices.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.article_outlined, color: Colors.indigo),
                            title: Text(_notices[index]),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
