import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF1C2137),
    body: Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: _DiagonalClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A4FC7), Color(0xFF3B9BF5)],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const SizedBox(height: 90),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'LOGO',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 18,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    color: Color(0xFFB0C8E8),
                    fontSize: 28,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'ClassHub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                SwipeToContinueButton(onComplete: onComplete),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.55, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width * 0.25, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class SwipeToContinueButton extends StatefulWidget {
  const SwipeToContinueButton({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<SwipeToContinueButton> createState() => _SwipeToContinueButtonState();
}

class _SwipeToContinueButtonState extends State<SwipeToContinueButton>
    with SingleTickerProviderStateMixin {
  static const _w = 300.0, _h = 56.0, _thumb = 44.0, _pad = 6.0;

  double _drag = 0;
  bool _done = false;
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  double get _max => _w - _thumb - _pad * 2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_done) return;
    setState(() => _drag = (_drag + d.delta.dx).clamp(0.0, _max));
  }

  void _onEnd(DragEndDetails _) {
    if (_done) return;
    if (_drag >= _max * 0.85) {
      setState(() {
        _drag = _max;
        _done = true;
      });
      widget.onComplete();
    } else {
      _anim = Tween<double>(begin: _drag, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      )..addListener(() => setState(() => _drag = _anim.value));
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _drag / _max;
    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: const Color(0xFF252A40),
        borderRadius: BorderRadius.circular(_h / 2),
        border: Border.all(color: const Color(0xFF3B4260)),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Center(
            child: Opacity(
              opacity: 1 - progress,
              child: const Padding(
                padding: EdgeInsets.only(left: 32),
                child: Text(
                  'Slide to continue',
                  style: TextStyle(
                    color: Color(0xFF8892B0),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: _pad + _drag,
            child: GestureDetector(
              onHorizontalDragUpdate: _onUpdate,
              onHorizontalDragEnd: _onEnd,
              child: Container(
                width: _thumb,
                height: _thumb,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_thumb / 2),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A4FC7), Color(0xFF3B9BF5)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B9BF5).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
