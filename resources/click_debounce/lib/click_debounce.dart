import 'dart:async';

import 'package:flutter/material.dart';

class ClickDebounce extends StatefulWidget {
  const ClickDebounce(
      {super.key, required this.count, required this.originStatus, this.onTap});

  final int count;

  final bool originStatus;

  final Function(int, bool)? onTap;

  @override
  State<ClickDebounce> createState() => _ClickDebounceState();
}

class _ClickDebounceState extends State<ClickDebounce> {
  int count = 0;
  bool status = false;

  Timer? debounce;

  @override
  void initState() {
    super.initState();
    count = widget.count;
    status = widget.originStatus;
  }

  @override
  void didUpdateWidget(covariant ClickDebounce oldWidget) {
    count = widget.count;
    status = widget.originStatus;
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void onTapItem() {
    status = !status;
    count += status ? 1 : -1;
    if (mounted) setState(() {});
    if (widget.onTap != null) {
      if (debounce?.isActive ?? false) debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 500), () {
        widget.onTap!(count, status);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapItem,
      child: Container(
        height: 100,
        width: 100,
        alignment: Alignment.center,
        color: status ? Colors.green : Colors.red,
        child: Text("$count"),
      ),
    );
  }
}
