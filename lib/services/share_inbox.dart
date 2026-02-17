import 'dart:async';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ShareInbox {
  final _controller = StreamController<String>.broadcast();
  Stream<String> get stream => _controller.stream;

  StreamSubscription<List<SharedMediaFile>>? _sub;

  Future<void> start() async {
    // Recebe compartilhamentos enquanto o app está aberto
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
          (items) async {
        await _handleSharedItems(items);
      },
      onError: (_) {},
    );

    // Recebe compartilhamento que abriu o app
    final initialItems = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialItems.isNotEmpty) {
      await _handleSharedItems(initialItems);
    }
  }

  Future<void> _handleSharedItems(List<SharedMediaFile> items) async {
    for (final item in items) {
      // Em muitos aparelhos, texto chega como SharedMediaType.TEXT e o conteúdo vem em item.path
      if (item.type == SharedMediaType.text) {
        final text = item.path.trim();
        if (text.isNotEmpty) _controller.add(text);
        continue;
      }

      // Alguns fabricantes/apps enviam "texto" como arquivo .txt.
      final path = item.path;
      if (path.endsWith('.txt')) {
        final file = File(path);
        if (await file.exists()) {
          final text = (await file.readAsString()).trim();
          if (text.isNotEmpty) _controller.add(text);
        }
      }
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
    ReceiveSharingIntent.instance.reset();
  }
}
