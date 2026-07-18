import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/tokens/colors.dart';
import '../../core/tokens/motion.dart';
import '../../core/tokens/typography.dart';
import '../../data/api/websocket_client.dart';

/// Thin amber strip under the app bar while the realtime socket is down —
/// the standard "Connecting…" cue. Zero-height when connected.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wsConnStateProvider).value ?? WsConnState.connected;
    final offline = state != WsConnState.connected;
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: Curves.easeOut,
      height: offline ? 26 : 0,
      color: AppColors.amberLight,
      child: offline
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.amberText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connecting…',
                  style: AppText.caption.copyWith(color: AppColors.amberText),
                ),
              ],
            )
          : null,
    );
  }
}
