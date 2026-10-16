import 'package:flutter/material.dart';

import '../../core/input_list.dart';
import '../../core/theme.dart';

class InputListEditor extends StatefulWidget {
  const InputListEditor({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  State<InputListEditor> createState() => _InputListEditorState();
}

class _InputListEditorState extends State<InputListEditor> {
  late List<_ChannelRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _rowsFrom(widget.controller.text);
    widget.controller.addListener(_onExternal);
  }

  @override
  void didUpdateWidget(InputListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onExternal);
      widget.controller.addListener(_onExternal);
      _replace(_rowsFrom(widget.controller.text));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternal);
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _onExternal() {
    if (widget.controller.text == encodeInputList(_values())) return;
    _replace(_rowsFrom(widget.controller.text));
  }

  void _replace(List<_ChannelRow> next) {
    final previous = _rows;
    setState(() => _rows = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in previous) {
        row.dispose();
      }
    });
  }

  List<_ChannelRow> _rowsFrom(String stored) {
    return [
      for (final channel in decodeInputList(stored))
        _ChannelRow.fromChannel(channel),
    ];
  }

  List<InputChannel> _values() {
    return [for (final row in _rows) row.channel];
  }

  void _emit() {
    final encoded = encodeInputList(_values());
    if (widget.controller.text == encoded) return;
    widget.controller.text = encoded;
  }

  void _insertAfter(int index) {
    final row = _ChannelRow();
    setState(() => _rows.insert(index + 1, row));
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.sourceFocus.requestFocus();
    });
  }

  void _delete(int index) {
    final removed = _rows[index];
    setState(() {
      _rows.removeAt(index);
      if (_rows.isEmpty) _rows.add(_ChannelRow());
    });
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inputliste / patch', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Trykk Enter i merknadsfeltet for å legge til neste kanal.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.onImageMuted,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _rows.length; index++) ...[
          _ChannelCard(
            number: index + 1,
            row: _rows[index],
            enabled: widget.enabled,
            onChanged: _emit,
            onSubmitNotes: () => _insertAfter(index),
            onDelete: () => _delete(index),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.number,
    required this.row,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitNotes,
    required this.onDelete,
  });

  final int number;
  final _ChannelRow row;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onSubmitNotes;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
      ),
      child: InkSurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Kanal $number',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Slett kanal $number',
                    onPressed: enabled ? onDelete : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              _Field(
                controller: row.source,
                focusNode: row.sourceFocus,
                label: 'Instrument / lydkilde',
                enabled: enabled,
                textInputAction: TextInputAction.next,
                onChanged: onChanged,
              ),
              _Field(
                controller: row.mic,
                focusNode: row.micFocus,
                label: 'Mikrofon / DI',
                enabled: enabled,
                textInputAction: TextInputAction.next,
                onChanged: onChanged,
              ),
              _Field(
                controller: row.stand,
                focusNode: row.standFocus,
                label: 'Stativ',
                enabled: enabled,
                textInputAction: TextInputAction.next,
                onChanged: onChanged,
              ),
              _Field(
                controller: row.notes,
                focusNode: row.notesFocus,
                label: 'Merknader / 48V',
                enabled: enabled,
                textInputAction: TextInputAction.done,
                onChanged: onChanged,
                onSubmitted: onSubmitNotes,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.enabled,
    required this.textInputAction,
    required this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool enabled;
  final TextInputAction textInputAction;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        textInputAction: textInputAction,
        onChanged: (_) => onChanged(),
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ChannelRow {
  _ChannelRow({
    String source = '',
    String mic = '',
    String stand = '',
    String notes = '',
  }) : source = TextEditingController(text: source),
       mic = TextEditingController(text: mic),
       stand = TextEditingController(text: stand),
       notes = TextEditingController(text: notes),
       sourceFocus = FocusNode(),
       micFocus = FocusNode(),
       standFocus = FocusNode(),
       notesFocus = FocusNode();

  factory _ChannelRow.fromChannel(InputChannel channel) {
    return _ChannelRow(
      source: channel.source,
      mic: channel.mic,
      stand: channel.stand,
      notes: channel.notes,
    );
  }

  final TextEditingController source;
  final TextEditingController mic;
  final TextEditingController stand;
  final TextEditingController notes;
  final FocusNode sourceFocus;
  final FocusNode micFocus;
  final FocusNode standFocus;
  final FocusNode notesFocus;

  InputChannel get channel => InputChannel(
    source: source.text,
    mic: mic.text,
    stand: stand.text,
    notes: notes.text,
  );

  void dispose() {
    source.dispose();
    mic.dispose();
    stand.dispose();
    notes.dispose();
    sourceFocus.dispose();
    micFocus.dispose();
    standFocus.dispose();
    notesFocus.dispose();
  }
}
