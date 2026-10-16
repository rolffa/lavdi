import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/portal_scope.dart';
import '../../core/rider_export.dart';
import '../../core/rider_text.dart';
import '../../core/theme.dart';
import '../../models/band.dart';
import '../../models/stage_plot.dart';
import '../../web/rider_files.dart';
import '../artist_portal/portal_widgets.dart';
import '../shell/portal_scaffold.dart';
import 'plan_tabs.dart';
import 'rider_documents.dart';
import 'rider_export_menu.dart';
import 'rider_view.dart';
import 'technical_rider_panel.dart';

class ArtistRidersPage extends StatefulWidget {
  const ArtistRidersPage({super.key});

  @override
  State<ArtistRidersPage> createState() => _ArtistRidersPageState();
}

class _ArtistRidersPageState extends State<ArtistRidersPage> {
  final _inputList = TextEditingController();
  final _monitors = TextEditingController();
  final _stageRig = TextEditingController();
  final _pa = TextEditingController();
  BandOverview? _overview;
  StagePlot? _plot;
  Object? _error;
  String? _message;
  var _loading = true;
  var _busy = false;
  var _hospitality = true;
  Uint8List? _logo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _inputList.dispose();
    _monitors.dispose();
    _stageRig.dispose();
    _pa.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await repository.fetchMyBand();
      final plot = overview == null ? null : await repository.fetchStagePlot();
      if (!mounted) return;
      if (overview != null) {
        _inputList.text = overview.band.inputList;
        _monitors.text = overview.band.monitors;
        _stageRig.text = overview.band.stageRig;
        _pa.text = overview.band.paRequirements;
      }
      setState(() {
        _overview = overview;
        _plot = plot;
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) _message = readableError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveTechnical() async {
    final current = _overview;
    if (current == null) return;
    await _run(() async {
      final band = await PortalScope.of(context).repository.saveTechnicalRider(
        inputList: _inputList.text,
        monitors: _monitors.text,
        stageRig: _stageRig.text,
        paRequirements: _pa.text,
      );
      _inputList.text = band.inputList;
      _monitors.text = band.monitors;
      _stageRig.text = band.stageRig;
      _pa.text = band.paRequirements;
      _overview = BandOverview(
        band: band,
        me: current.me,
        members: current.members,
        invites: current.invites,
      );
      _message = 'Teknisk rider er lagret.';
    });
  }

  Future<void> _uploadPlot() async {
    final picked = await pickStagePlotFile();
    if (picked == null || !mounted) return;
    final current = _overview;
    if (current == null) return;
    await _run(() async {
      final plot = await PortalScope.of(context).repository
          .uploadStagePlot(filename: picked.name, bytes: picked.bytes);
      _plot = plot;
      _overview = BandOverview(
        band: current.band.copyWith(
          stagePlotPath: plot.path,
          stagePlotName: plot.name,
          stagePlotType: plot.contentType,
        ),
        me: current.me,
        members: current.members,
        invites: current.invites,
      );
      _message = 'Scenekartet er lastet opp.';
    });
  }

  Future<void> _clearPlot() async {
    final current = _overview;
    if (current == null) return;
    await _run(() async {
      await PortalScope.of(context).repository.clearStagePlot();
      _plot = null;
      _overview = BandOverview(
        band: current.band.copyWith(
          stagePlotPath: '',
          stagePlotName: '',
          stagePlotType: '',
        ),
        me: current.me,
        members: current.members,
        invites: current.invites,
      );
      _message = 'Scenekartet er fjernet.';
    });
  }

  Future<void> _downloadPlot() async {
    final plot = _plot;
    if (plot == null) return;
    saveBytes(plot.bytes, plot.name, plot.contentType);
  }

  Future<void> _export(RiderExport kind) async {
    final overview = _overview;
    if (overview == null || _busy) return;
    final gaps = riderProfileGaps(kind, overview.members);
    if (gaps.isNotEmpty) {
      final proceed = await confirmRiderGaps(context, gaps);
      if (!proceed || !mounted) return;
    }
    await _run(() async {
      final data = await rootBundle.load('assets/brand/logo2.png');
      _logo ??= data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final updatedAt = DateTime.now();
      final bytes = await buildRiderPdf(
        kind: kind,
        band: overview.band,
        members: overview.members,
        stagePlot: kind == RiderExport.hospitality ? null : _plot,
        logo: _logo,
        updatedAt: updatedAt,
      );
      saveBytes(
        bytes,
        riderPdfFileName(kind, overview.band.name, updatedAt),
        'application/pdf',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = _hospitality ? RiderKind.hospitality : RiderKind.technical;
    final overview = _overview;
    return PortalScaffold(
      artistMenu: true,
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                ArtistFrame(
                  child: _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ridere', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
                            const SizedBox(height: 8),
                            Text(
                              'Hospitality og teknisk rider hentes fra bandet og er like for alle konserter.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.onImageMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _KindButton(
                                  label: 'Hospitality',
                                  selected: _hospitality,
                                  onPressed: () =>
                                      setState(() => _hospitality = true),
                                ),
                                _KindButton(
                                  label: 'Teknisk',
                                  selected: !_hospitality,
                                  onPressed: () =>
                                      setState(() => _hospitality = false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_message != null) ...[
                              Text(
                                _message!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onImage,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (overview == null)
                              const Text(
                                'Bandet har ikke lagt inn en rider ennå.',
                              )
                            else ...[
                              RiderExportMenu(busy: _busy, onExport: _export),
                              const SizedBox(height: 20),
                              if (!_hospitality) ...[
                                TechnicalRiderPanel(
                                  leader: overview.me.isLeader,
                                  busy: _busy,
                                  plot: _plot,
                                  inputList: _inputList,
                                  monitors: _monitors,
                                  stageRig: _stageRig,
                                  paRequirements: _pa,
                                  onSave: _saveTechnical,
                                  onUpload: _uploadPlot,
                                  onClear: _clearPlot,
                                  onDownloadPlot: _downloadPlot,
                                ),
                                const SizedBox(height: 20),
                              ],
                              RiderView(
                                kind: kind,
                                band: overview.band,
                                members: overview.members,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class ProductionRiderPage extends StatefulWidget {
  const ProductionRiderPage({
    super.key,
    required this.bookingToken,
    required this.kind,
  });

  final String bookingToken;
  final RiderKind kind;

  @override
  State<ProductionRiderPage> createState() => _ProductionRiderPageState();
}

class _ProductionRiderPageState extends State<ProductionRiderPage> {
  BandRoster? _roster;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repository = PortalScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roster = await repository.fetchRiders(widget.bookingToken);
      if (!mounted) return;
      setState(() {
        _roster = roster;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.kind == RiderKind.hospitality
        ? 'Hospitality rider'
        : 'Teknisk rider';
    final tab = widget.kind == RiderKind.hospitality
        ? 'Hospitality'
        : 'Teknisk rider';
    return PortalScaffold(
      body: _loading
          ? const CenteredStatus(child: CircularProgressIndicator())
          : ListView(
              children: [
                PageFrame(
                  maxWidth: 760,
                  child: _error != null
                      ? ErrorRetry(
                          message: readableError(_error!),
                          onRetry: _load,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlanTabs(
                              current: tab,
                              basePath: '/production/${widget.bookingToken}',
                            ),
                            const SizedBox(height: 20),
                            Text(title, style: theme.textTheme.displaySmall?.copyWith(color: AppColors.onImage)),
                            const SizedBox(height: 12),
                            if (_roster == null)
                              const Text(
                                'Bandet har ikke lagt inn en rider ennå.',
                              )
                            else
                              RiderView(
                                kind: widget.kind,
                                band: _roster!.band,
                                members: _roster!.members,
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}
