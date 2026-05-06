import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});
  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  bool _isExpanded = false;
  bool _isOnRightSide = true;
  bool _isOnBottomSide = false;
  bool _isRecording = false;
  String _duration = "00:00";
  double? _origX;
  double? _origY;
  double _screenWidthDp = 360.0;
  double _screenHeightDp = 640.0;

  // 좌표계: OverlayAlignment.topLeft (상단 좌측 기준)
  // 화면 너비 약 360dp. 창 크기는 60dp.
  double _posX = 300.0; // 360 - 60 = 300 (우측 끝)
  double _posY = 200.0; // 상단에서 200dp 아래

  static const double kBall = 54.0;
  static const double kWinCollapsed = 60.0;
  static const double kWinExpanded = 240.0;
  static const double kR = 82.0;
  static const double kIcon = 44.0;

  @override
  void initState() {
    super.initState();
    _loadInitialPosition(); // 초기 위치 로드
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _duration = data['duration'] ?? "00:00";
          _isRecording = data['status'] == 'recording';
        });
      }
    });
  }

  Future<void> _loadInitialPosition() async {
    const channel = MethodChannel('x-slayer/overlay');
    final data = await channel.invokeMethod('getOverlayPosition');
    if (data != null && mounted) {
      setState(() {
        _posX = (data['x'] as num).toDouble();
        _posY = (data['y'] as num).toDouble();
      });
    }
  }

  String _alignment = "topLeft";
  double _anchorX = 0;
  double _anchorY = 0;

  Future<void> _toggleExpand() async {
    const channel = MethodChannel('x-slayer/overlay');
    final view = PlatformDispatcher.instance.views.first;
    _screenWidthDp = view.display.size.width / view.devicePixelRatio;
    _screenHeightDp = view.display.size.height / view.devicePixelRatio;

    if (!_isExpanded) {
      // 1. 진짜 현재 위치(좌측 상단) 가져오기
      final Map<dynamic, dynamic>? pos = await channel.invokeMethod('getOverlayPosition');
      if (pos != null) {
        _posX = (pos['x'] as num).toDouble();
        _posY = (pos['y'] as num).toDouble();
      }

      // 2. 가장 가까운 모서리 결정 (동적 앵커링)
      bool isLeft = _posX < (_screenWidthDp / 2);
      bool isTop = _posY < (_screenHeightDp / 2);
      
      if (isTop && isLeft) _alignment = "topLeft";
      else if (isTop && !isLeft) _alignment = "topRight";
      else if (!isTop && isLeft) _alignment = "bottomLeft";
      else if (!isTop && !isLeft) _alignment = "bottomRight";

      _isOnRightSide = !isLeft;
      _isOnBottomSide = !isTop;

      // 3. 해당 앵커 기준의 물리적 거리(DP) 계산
      _anchorX = isLeft ? _posX : (_screenWidthDp - (_posX + kWinCollapsed));
      _anchorY = isTop ? _posY : (_screenHeightDp - (_posY + kWinCollapsed));

      // 4. 비대칭 확장 (Asymmetric Expansion) - 볼이 있는 모서리를 고정!
      // 안드로이드는 고정된 모서리를 기준으로 창을 키우기 때문에 볼의 물리적 위치가 절대 변하지 않습니다.
      await channel.invokeMethod('moveAndResize', {
        'x': _anchorX.toInt(),
        'y': _anchorY.toInt(),
        'width': kWinExpanded.toInt(),
        'height': kWinExpanded.toInt(),
        'alignment': _alignment,
      });

      if (!mounted) return;
      setState(() {
        _isExpanded = true;
      });
    } else {
      // 1. 같은 앵커를 유지한 채로 크기만 축소 (볼이 튀는 현상 완벽 방지)
      await channel.invokeMethod('moveAndResize', {
        'x': _anchorX.toInt(),
        'y': _anchorY.toInt(),
        'width': kWinCollapsed.toInt(),
        'height': kWinCollapsed.toInt(),
        'alignment': _alignment,
      });

      setState(() => _isExpanded = false);

      // 2. 애니메이션이 끝난 후(350ms) 다음 드래그를 위해 남몰래 topLeft 기준으로 원상복구
      Future.delayed(const Duration(milliseconds: 350), () async {
        if (!mounted || _isExpanded) return;
        await channel.invokeMethod('moveAndResize', {
          'x': _posX.toInt(),
          'y': _posY.toInt(),
          'width': kWinCollapsed.toInt(),
          'height': kWinCollapsed.toInt(),
          'alignment': 'topLeft',
        });
      });
    }
  }

  List<Map<String, dynamic>> _menuItems() {
    double centerAngle;
    double sweepRange;

    // 현재 화면의 Y 위치를 기준으로 팬 각도(t)를 계산 (화면 위 0.0 ~ 화면 아래 1.0)
    final t = (_posY / (_screenHeightDp - kBall)).clamp(0.0, 1.0); 

    if (_isOnRightSide) {
      // 우측일 때: 상단(135도) -> 중앙(180도) -> 하단(225도)으로 부드럽게 변화
      centerAngle = (135 + (90 * t)) * math.pi / 180;
    } else {
      // 좌측일 때: 상단(45도) -> 중앙(0도) -> 하단(-45도/315도)으로 부드럽게 변화
      centerAngle = (45 - (90 * t)) * math.pi / 180;
    }

    // 펼쳐지는 범위: 양 끝에서는 90도, 중앙으로 올수록 최대 160도까지 Sine 곡선을 그리며 확장
    sweepRange = (90 + (70 * math.sin(t * math.pi))) * math.pi / 180;

    final icons = [
      {'icon': Icons.fiber_manual_record, 'color': Colors.red,    'id': 'record'},
      {'icon': Icons.home_rounded,        'color': Colors.orange,  'id': 'home'},
      {'icon': Icons.camera_alt_rounded,  'color': Colors.blue,    'id': 'shot'},
      {'icon': Icons.videocam_rounded,    'color': Colors.green,   'id': 'cam'},
      {'icon': Icons.close_rounded,       'color': Colors.grey.shade700, 'id': 'close'},
    ];
    
    for (int i = 0; i < icons.length; i++) {
      final t = i / (icons.length - 1);
      icons[i]['angle'] = centerAngle + (t - 0.5) * sweepRange;
    }
    return icons;
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Anchoring 방식: 
    // 네이티브 창이 모서리를 고정하고 크기를 키우므로,
    // 플러터도 동일한 모서리에 볼을 Positioned로 고정해두면 절대 움직이지 않습니다.
    double currentSize = _isExpanded ? kWinExpanded : kWinCollapsed;

    double? left, right, top, bottom;
    if (_alignment == "topLeft") { left = 0; top = 0; }
    else if (_alignment == "topRight") { right = 0; top = 0; }
    else if (_alignment == "bottomLeft") { left = 0; bottom = 0; }
    else if (_alignment == "bottomRight") { right = 0; bottom = 0; }

    return Container(
      width: currentSize,
      height: currentSize,
      color: Colors.transparent, // 투명 배경을 유지
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_isExpanded)
            // 메뉴 바깥쪽 터치 감지
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleExpand,
                child: Container(color: Colors.transparent),
              ),
            ),
          
          ..._menuItems().map((item) {
            final angle = item['angle'] as double;
            const double r = 95.0;
            
            // 볼의 가상 중심 좌표 (300x300 창 내부 기준)
            double cx = _alignment.contains("Left") ? kBall / 2 : kWinExpanded - (kBall / 2);
            double cy = _alignment.contains("Top") ? kBall / 2 : kWinExpanded - (kBall / 2);

            final tx = cx + r * math.cos(angle) - (kIcon / 2);
            final ty = cy + r * math.sin(angle) - (kIcon / 2);

            // 축소 상태일 때는 볼 안쪽(가상 중심)에 숨겨두고, 확장 시 목표 위치로 팝업!
            final targetX = _isExpanded ? tx : cx - (kIcon / 2);
            final targetY = _isExpanded ? ty : cy - (kIcon / 2);

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: targetX, top: targetY,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded ? 1.0 : 0.0,
                child: GestureDetector(
                  onTap: () {
                    if (_isExpanded) _onTap(item['id'] as String);
                  },
                  child: Container(
                    width: kIcon, height: kIcon,
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8, spreadRadius: 1,
                      )],
                    ),
                    child: Icon(item['icon'] as IconData,
                        color: item['color'] as Color, size: 23),
                  ),
                ),
              ),
            );
          }),
          
          Positioned(
            left: left, right: right, top: top, bottom: bottom,
            child: GestureDetector(
              onTap: _toggleExpand,
              child: Container(
                width: kBall, height: kBall,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isRecording
                        ? [Colors.red.shade400, Colors.red.shade900]
                        : [const Color(0xFFFF7043), const Color(0xFFBF360C)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(
                    color: (_isRecording ? Colors.red : const Color(0xFFFF7043))
                        .withValues(alpha: 0.6),
                    blurRadius: 16, spreadRadius: 2,
                  )],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isRecording ? Icons.stop : Icons.videocam,
                        color: Colors.white, size: 24),
                    if (_isRecording)
                      Text(_duration, style: const TextStyle(
                          color: Colors.white, fontSize: 8,
                          fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 안드로이드 네이티브가 터치와 드래그, 좌우 스냅을 모두 완벽하게 처리하므로 
  // 플러터에서의 수동 드래그 처리(_onPanUpdate, _onPanEnd)는 제거하여 충돌(desync)을 방지합니다.

  Future<void> _onTap(String id) async {
    if (id == 'close') { await FlutterOverlayWindow.closeOverlay(); return; }
    if (id == 'record') {
      await FlutterOverlayWindow.shareData(_isRecording ? 'stop' : 'start');
    }
    await _toggleExpand(); // 다시 await 추가
  }
}
