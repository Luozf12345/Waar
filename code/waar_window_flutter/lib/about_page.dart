import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kAppVersion = '0.0.1';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _changelog = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    final text = await rootBundle.loadString('ChangeLog.md');
    if (mounted) {
      setState(() {
        _changelog = text.trim();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
        backgroundColor: cs.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 48, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Waar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$kAppVersion',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildChangelogSections(cs),
              ],
            ),
    );
  }

  List<Widget> _buildChangelogSections(ColorScheme cs) {
    final sections = <Widget>[];
    String? currentTitle;
    final lines = <String>[];

    void flush() {
      final title = currentTitle;
      if (title == null) return;
      sections.add(_ChangelogSection(
        title: title,
        lines: List.unmodifiable(lines),
        colorScheme: cs,
      ));
      lines.clear();
      currentTitle = null;
    }

    for (final raw in _changelog.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('# ')) {
        flush();
        currentTitle = line.substring(2).trim();
      } else if (currentTitle != null && line.isNotEmpty) {
        lines.add(line);
      }
    }
    flush();
    return sections;
  }
}

class _ChangelogSection extends StatelessWidget {
  final String title;
  final List<String> lines;
  final ColorScheme colorScheme;

  const _ChangelogSection({
    required this.title,
    required this.lines,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SelectableText(
                      line,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
