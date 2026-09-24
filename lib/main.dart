import 'package:flutter/material.dart';
import 'package:gimii_flutter/gimii_flutter.dart';

/// Values provided by Gimii, read from `.env` at build time:
/// `flutter run --dart-define-from-file=.env`
const _raiserId = String.fromEnvironment('GIMII_RAISER_ID');
const _didomiApiKey = String.fromEnvironment('GIMII_DIDOMI_API_KEY');
const _didomiNoticeId = String.fromEnvironment('GIMII_DIDOMI_NOTICE_ID');

void main() => runApp(const SampleApp());

class SampleApp extends StatelessWidget {
  const SampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gimii — Flutter sample',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1F4F5F),
          useMaterial3: true,
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<String> _log = [];
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    // Subscribe before calling `initialize`: the SDK fails silently, and a
    // `GimiiFailed` event is often the only information you will get.
    Gimii.events.listen(_onEvent, onError: (e) => _append('stream: $e'));
    _configure();
  }

  /// Events are sealed types: the compiler reminds you of any unhandled case.
  void _onEvent(GimiiEvent e) {
    switch (e) {
      case GimiiDisplayed():
        _append('pop-in displayed');
      case GimiiAccepted():
        _append('charity selected — ad targeting is now available');
      case GimiiRefused():
        _append('refused');
      case GimiiFailed(:final error):
        _append('failed: $error');
    }
  }

  Future<void> _configure() async {
    if (_raiserId.isEmpty || _didomiApiKey.isEmpty || _didomiNoticeId.isEmpty) {
      // Called from initState, before the first build: no setState needed.
      _log.add('Missing configuration: copy .env.example to .env, fill it in, '
          'then run flutter run --dart-define-from-file=.env');
      return;
    }
    await _run(
      'initialize',
      () => Gimii.initialize(
        raiserId: _raiserId,
        didomiApiKey: _didomiApiKey,
        didomiNoticeId: _didomiNoticeId,
        environment: GimiiEnvironment.staging,
        debug: true,
      ),
    );
    // As in the native samples: the consent notice appears at startup, and
    // Gimii runs as soon as the user refuses it.
    await _run('execute', Gimii.execute);
  }

  Future<void> _run(String label, Future<Object?> Function() action) async {
    try {
      final result = await action();
      _append(result == null ? '$label ✓' : '$label → $result');
    } catch (e) {
      _append('$label ✗ $e');
    }
  }

  void _append(String line) {
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Gimii — Flutter sample'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Runs the SDK: the pop-in appears only if the consent
                      // and the display delay allow it.
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _run('execute', Gimii.execute),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Run Gimii'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _run('adTargeting', () async {
                            final tags = await Gimii.adTargeting();
                            return tags.isEmpty
                                ? 'no tags yet (no charity selected)'
                                : tags.entries.map((e) => '${e.key}=${e.value}').join(', ');
                          }),
                          child: const Text('Ad targeting'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Back to a fresh install: consent notice and pop-in show again.
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _taps = 0;
                            _log.clear();
                          });
                          _run('reset', Gimii.reset);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('List taps: $_taps'),
                  ),
                ],
              ),
            ),
            _EventLog(lines: _log),
            const Divider(height: 1),
            // Touch pass-through probe: if this list scrolls while the pop-in is
            // displayed, touches correctly go through its transparent areas.
            Expanded(
              child: ListView.separated(
                itemCount: 60,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        Colors.primaries[i % Colors.primaries.length].shade200,
                    child: Text('$i', style: const TextStyle(fontSize: 11)),
                  ),
                  title: Text('List item #$i'),
                  subtitle: const Text('Scroll here while the pop-in is displayed'),
                  onTap: () => setState(() => _taps++),
                ),
              ),
            ),
          ],
        ),
      );
}

class _EventLog extends StatelessWidget {
  const _EventLog({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        height: 170,
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF14181C),
          borderRadius: BorderRadius.circular(10),
        ),
        child: lines.isEmpty
            ? const Text(
                'Waiting for SDK events…',
                style: TextStyle(
                  color: Color(0xFF6B7A80),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              )
            : ListView(
                children: lines
                    .asMap()
                    .entries
                    .map((e) => Text(
                          e.value,
                          style: TextStyle(
                            color: e.key == 0
                                ? const Color(0xFF9FE8C8)
                                : const Color(0xFF7C8B91),
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
      );
}
