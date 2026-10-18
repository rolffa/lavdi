import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../core/tono.dart';
import '../../models/repertoire.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class SetlistPage extends StatefulWidget {
  const SetlistPage({super.key, required this.gigId});

  final String gigId;

  @override
  State<SetlistPage> createState() => _SetlistPageState();
}

class _SetlistPageState extends State<SetlistPage> {
  List<RepertoireTrack> _bank = const [];
  List<SetlistTrack> _played = [];
  String? _tonoText;
  var _confirmed = false;
  Object? _error;
  String? _formError;
  var _loading = true;
  var _saving = false;
  var _signedOut = false;
  final _extraTitle = TextEditingController();
  final _extraDuration = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _extraTitle.dispose();
    _extraDuration.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await repository.currentArtist();
      if (session == null) {
        if (!mounted) return;
        setState(() {
          _signedOut = true;
          _loading = false;
        });
        return;
      }
      final bank = await repository.fetchRepertoire();
      final setlist = await repository.fetchSetlist(widget.gigId);
      if (!mounted) return;
      setState(() {
        _bank = bank;
        _played = List.of(setlist.tracks);
        _tonoText = setlist.confirmed ? setlist.tonoText : null;
        _confirmed = setlist.confirmed;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool _selected(RepertoireTrack track) {
    return _played.any((item) => item.repertoireId == track.id);
  }

  void _toggle(RepertoireTrack track, bool selected) {
    setState(() {
      if (selected) {
        _played.add(
          SetlistTrack(
            title: track.title,
            duration: track.duration,
            repertoireId: track.id,
          ),
        );
      } else {
        _played.removeWhere((item) => item.repertoireId == track.id);
      }
    });
  }

  void _move(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _played.length) return;
    setState(() {
      final track = _played.removeAt(index);
      _played.insert(next, track);
    });
  }

  void _addExtra() {
    final duration = normalizePlayTime(_extraDuration.text);
    if (_extraTitle.text.trim().isEmpty || duration == null) {
      setState(
        () => _formError = 'Ekstra låt trenger tittel og spilletid 03:45.',
      );
      return;
    }
    setState(() {
      _formError = null;
      _played.add(
        SetlistTrack(
          title: _extraTitle.text.trim(),
          duration: duration,
          extra: true,
        ),
      );
      _extraTitle.clear();
      _extraDuration.clear();
    });
  }

  Future<void> _save() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      final saved = await repository.saveSetlist(
        gigId: widget.gigId,
        tracks: _played,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmed = true;
        _tonoText = saved.tonoText;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = readableError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                ArtistFrame(
                  child: _signedOut
                      ? const Text('Logg inn for å bekrefte settlisten.')
                      : _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArtistBackButton(
                              label: 'Konserten',
                              path: '/min-side/gig/${widget.gigId}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Settliste',
                              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Huk av låtene som ble spilt. Listen lagres på konserten, klar til TONO.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            if (_confirmed) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Settlisten er bekreftet.',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.onImage,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text('LÅTBANK', style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.onImageMuted,
                              )),
                            const SizedBox(height: 8),
                            for (final track in _bank)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _selected(track),
                                onChanged: (value) =>
                                    _toggle(track, value ?? false),
                                title: Text(track.title),
                                subtitle: Text(track.duration),
                              ),
                            const SizedBox(height: 20),
                            Text('SPILT', style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.onImageMuted,
                              )),
                            const SizedBox(height: 8),
                            if (_played.isEmpty)
                              const Text('Ingen låter er huket av ennå.')
                            else
                              for (
                                var index = 0;
                                index < _played.length;
                                index++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ArtistCard(
                                    child: Row(
                                      children: [
                                        Text('${index + 1}'),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(_played[index].title),
                                              Text(_played[index].duration),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Flytt opp',
                                          onPressed: index == 0
                                              ? null
                                              : () => _move(index, -1),
                                          icon: const Icon(Icons.arrow_upward),
                                        ),
                                        IconButton(
                                          tooltip: 'Flytt ned',
                                          onPressed: index == _played.length - 1
                                              ? null
                                              : () => _move(index, 1),
                                          icon: const Icon(
                                            Icons.arrow_downward,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            const SizedBox(height: 16),
                            Text(
                              'EKSTRA LÅT',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _extraTitle,
                              style: portalFieldStyle,
                              cursorColor: AppColors.ink,
                              decoration: fieldDecoration(label: 'Tittel'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _extraDuration,
                              style: portalFieldStyle,
                              cursorColor: AppColors.ink,
                              decoration: fieldDecoration(
                                label: 'Spilletid (03:45)',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _addExtra,
                              child: const Text('Legg til ekstra låt'),
                            ),
                            if (_formError != null) ...[
                              const SizedBox(height: 12),
                              FieldError(_formError!),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _saving ? null : _save,
                                child: Text(
                                  _saving ? 'Lagrer…' : 'Lagre settliste',
                                ),
                              ),
                            ),
                            if (_tonoText != null && _tonoText!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                'KLAR TIL TONO',
                                style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                              ),
                              const SizedBox(height: 8),
                              ArtistCard(child: SelectableText(_tonoText!)),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
