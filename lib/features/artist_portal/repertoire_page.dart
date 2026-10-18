import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/theme.dart';
import '../../core/tono.dart';
import '../../models/repertoire.dart';
import '../shell/portal_scaffold.dart';
import 'portal_widgets.dart';

class RepertoirePage extends StatefulWidget {
  const RepertoirePage({super.key});

  @override
  State<RepertoirePage> createState() => _RepertoirePageState();
}

class _RepertoirePageState extends State<RepertoirePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _duration = TextEditingController();
  List<RepertoireTrack> _tracks = const [];
  String? _editingId;
  Object? _error;
  String? _formError;
  var _loading = true;
  var _saving = false;
  var _signedOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
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
      final tracks = await repository.fetchRepertoire();
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
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

  void _edit(RepertoireTrack track) {
    setState(() {
      _editingId = track.id;
      _title.text = track.title;
      _duration.text = track.duration;
    });
  }

  void _clearForm() {
    _editingId = null;
    _title.clear();
    _duration.clear();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final repository = PortalScope.of(context).repository;
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await repository.saveRepertoireTrack(
        id: _editingId,
        title: _title.text,
        duration: _duration.text,
      );
      _clearForm();
      final tracks = await repository.fetchRepertoire();
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = readableError(error);
      });
    }
  }

  Future<void> _delete(RepertoireTrack track) async {
    final repository = PortalScope.of(context).repository;
    await repository.deleteRepertoireTrack(track.id);
    if (_editingId == track.id) _clearForm();
    final tracks = await repository.fetchRepertoire();
    if (!mounted) return;
    setState(() => _tracks = tracks);
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
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArtistBackButton(
                              label: 'Settliste',
                              path: '/min-side/settliste',
                            ),
                            SizedBox(height: 12),
                            Text('Logg inn for å se repertoaret.'),
                          ],
                        )
                      : _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ArtistBackButton(
                              label: 'Settliste',
                              path: '/min-side/settliste',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mitt repertoar',
                              style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Låtene lagres én gang og brukes når settlisten skal bekreftes.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  PortalTextFormField(
                                    controller: _title,
                                    label: 'Tittel',
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Oppgi tittel'
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  PortalTextFormField(
                                    controller: _duration,
                                    label: 'Spilletid (03:45)',
                                    keyboardType: TextInputType.datetime,
                                    validator: (value) =>
                                        normalizePlayTime(value ?? '') == null
                                        ? 'Bruk formen 03:45'
                                        : null,
                                  ),
                                  if (_formError != null) ...[
                                    const SizedBox(height: 12),
                                    FieldError(_formError!),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _saving ? null : _save,
                                      child: Text(
                                        _saving
                                            ? 'Lagrer…'
                                            : _editingId == null
                                            ? 'Legg til låt'
                                            : 'Oppdater låt',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            for (final track in _tracks) ...[
                              ArtistCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _edit(track),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.title,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(color: AppColors.ink),
                                            ),
                                            Text(track.duration),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Slett',
                                      onPressed: () => _delete(track),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
