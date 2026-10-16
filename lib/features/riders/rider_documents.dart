import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../core/input_list.dart';
import '../../core/rider_export.dart';
import '../../models/band.dart';
import '../../models/stage_plot.dart';

const _ink = PdfColor.fromInt(0xFF161513);
const _muted = PdfColor.fromInt(0xFF6E6960);
const _line = PdfColor.fromInt(0xFFDDD6C8);

class TechnicalRiderDocument {
  const TechnicalRiderDocument({
    required this.band,
    required this.members,
    this.stagePlot,
    required this.updatedAt,
    this.logo,
  });

  final Band band;
  final List<BandMember> members;
  final StagePlot? stagePlot;
  final DateTime updatedAt;
  final Uint8List? logo;

  Future<Uint8List> save({bool compress = true}) {
    final layout = _Layout(band: band, updatedAt: updatedAt, logo: logo);
    final document = layout.document(compress: compress);
    layout.addSection(
      document,
      title: 'Teknisk rider',
      sections: layout.technical(members),
    );
    final plot = stagePlot;
    if (plot != null) layout.addStagePlot(document, plot);
    return document.save();
  }
}

class HospitalityRiderDocument {
  const HospitalityRiderDocument({
    required this.band,
    required this.members,
    required this.updatedAt,
    this.logo,
  });

  final Band band;
  final List<BandMember> members;
  final DateTime updatedAt;
  final Uint8List? logo;

  Future<Uint8List> save({bool compress = true}) {
    final layout = _Layout(band: band, updatedAt: updatedAt, logo: logo);
    final document = layout.document(compress: compress);
    layout.addSection(
      document,
      title: 'Hospitality rider',
      sections: layout.hospitality(members),
    );
    return document.save();
  }
}

class CombinedRiderDocument {
  const CombinedRiderDocument({
    required this.band,
    required this.members,
    this.stagePlot,
    required this.updatedAt,
    this.logo,
  });

  final Band band;
  final List<BandMember> members;
  final StagePlot? stagePlot;
  final DateTime updatedAt;
  final Uint8List? logo;

  Future<Uint8List> save({bool compress = true}) {
    final layout = _Layout(band: band, updatedAt: updatedAt, logo: logo);
    final document = layout.document(compress: compress);
    layout.addSection(
      document,
      title: 'Hospitality rider',
      sections: layout.hospitality(members),
    );
    layout.addSection(
      document,
      title: 'Teknisk rider',
      sections: layout.technical(members),
    );
    final plot = stagePlot;
    if (plot != null) layout.addStagePlot(document, plot);
    return document.save();
  }
}

Future<Uint8List> buildRiderPdf({
  required RiderExport kind,
  required Band band,
  required List<BandMember> members,
  StagePlot? stagePlot,
  Uint8List? logo,
  DateTime? updatedAt,
  bool compress = true,
}) {
  final when = updatedAt ?? DateTime.now();
  return switch (kind) {
    RiderExport.technical => TechnicalRiderDocument(
      band: band,
      members: members,
      stagePlot: stagePlot,
      updatedAt: when,
      logo: logo,
    ).save(compress: compress),
    RiderExport.hospitality => HospitalityRiderDocument(
      band: band,
      members: members,
      updatedAt: when,
      logo: logo,
    ).save(compress: compress),
    RiderExport.complete => CombinedRiderDocument(
      band: band,
      members: members,
      stagePlot: stagePlot,
      updatedAt: when,
      logo: logo,
    ).save(compress: compress),
  };
}

class _Layout {
  _Layout({required this.band, required this.updatedAt, Uint8List? logo})
    : mark = _mark(logo);

  final Band band;
  final DateTime updatedAt;
  final pw.ImageProvider? mark;

  pw.Document document({required bool compress}) {
    return pw.Document(
      compress: compress,
      title: 'Lávdi rider',
      author: 'Amundsen Studio',
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );
  }

  void addSection(
    pw.Document document, {
    required String title,
    required List<pw.Widget> sections,
  }) {
    document.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        header: (context) => _header(title),
        footer: _footer,
        build: (context) => sections,
      ),
    );
  }

  void addStagePlot(pw.Document document, StagePlot plot) {
    document.addPage(
      pw.Page(
        pageTheme: _pageTheme(),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header('Scenekart / Stage Plot'),
            pw.Text(plot.name, style: _small),
            pw.SizedBox(height: 16),
            pw.Expanded(child: _plotGraphic(plot)),
            pw.SizedBox(height: 12),
            _footer(context),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> technical(List<BandMember> members) {
    return [
      _intro(),
      ..._inputListSection(band.inputList),
      _block('Monitorbehov', band.monitors),
      _block('DJ / scenerigg', band.stageRig),
      _block('PA-krav', band.paRequirements),
      _block('Felles teknisk oppsett', band.sharedTech),
      _people(
        title: 'Personlige tekniske behov',
        members: members,
        lines: (member) => [
          _labeled(
            'Personlig teknikk',
            _filled(member.personalTech, empty: 'Ikke utfylt'),
          ),
        ],
      ),
    ];
  }

  List<pw.Widget> hospitality(List<BandMember> members) {
    return [
      _intro(),
      _block('Romfordeling og losji', band.sharedHospitality),
      _people(
        title: 'Mat, dietter og allergier',
        members: members,
        lines: (member) => [
          _labeled('Telefon', _filled(member.phone)),
          _labeled('Mat', _filled(member.food, empty: 'Ikke utfylt')),
        ],
      ),
    ];
  }

  pw.Widget _intro() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          band.name.trim().isEmpty ? 'Uten bandnavn' : band.name.trim(),
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 8),
        _labeled('Kontakt', _filled(band.contact)),
        pw.SizedBox(height: 4),
        pw.Text('Oppdatert ${formatLongDate(updatedAt)}', style: _small),
      ],
    );
  }

  pw.Widget _header(String title) {
    final image = mark;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (image != null)
              pw.Image(image, height: 22)
            else
              pw.Text(
                'LÁVDI',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2.2,
                  color: _ink,
                ),
              ),
            pw.Text('Amundsen Studio', style: _small),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 0.6, color: _ink),
        pw.SizedBox(height: 14),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 10),
      ],
    );
  }
}

pw.PageTheme _pageTheme() {
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(46, 40, 46, 40),
  );
}

pw.Widget _footer(pw.Context context) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _line, width: 0.6)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Lávdi · Amundsen Studio', style: _small),
        pw.Text('${context.pageNumber} / ${context.pagesCount}', style: _small),
      ],
    ),
  );
}

const _inputHeaders = [
  'Ch #',
  'Source / Instrument',
  'Mic / DI',
  'Stand',
  'Notes / 48V',
];
const _inputStripe = PdfColor.fromInt(0xFFF3F0E8);
const _inputPaper = PdfColor.fromInt(0xFFFFFCF8);

List<pw.Widget> _inputListSection(String stored) {
  final rows = filledInputChannels(stored);
  if (rows.isEmpty) return [_block('Inputliste / patch', '')];
  return [
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text('INPUTLISTE / PATCH', style: _label),
    ),
    _inputRow(
      values: _inputHeaders,
      background: _ink,
      header: true,
      topBorder: true,
    ),
    for (var index = 0; index < rows.length; index++)
      _inputRow(
        values: [
          '${index + 1}',
          rows[index].source,
          rows[index].mic,
          rows[index].stand,
          rows[index].notes,
        ],
        background: index.isOdd ? _inputStripe : _inputPaper,
        emphasizeFirst: true,
      ),
  ];
}

pw.Widget _inputRow({
  required List<String> values,
  required PdfColor background,
  bool header = false,
  bool topBorder = false,
  bool emphasizeFirst = false,
}) {
  final line = pw.BorderSide(color: header ? _ink : _line, width: 0.4);
  return pw.Table(
    border: pw.TableBorder(
      top: topBorder ? line : pw.BorderSide.none,
      bottom: line,
      left: line,
      right: line,
      verticalInside: line,
    ),
    columnWidths: const {
      0: pw.FixedColumnWidth(34),
      1: pw.FlexColumnWidth(2.4),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(1.5),
      4: pw.FlexColumnWidth(2),
    },
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: background),
        children: [
          for (var index = 0; index < values.length; index++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 5,
              ),
              child: pw.Text(
                values[index],
                textAlign: index == 0 ? pw.TextAlign.center : pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: header ? 8 : 9,
                  fontWeight: header || (emphasizeFirst && index == 0)
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: header ? PdfColors.white : _ink,
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

pw.Widget _block(String title, String body) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title.toUpperCase(), style: _label),
        pw.SizedBox(height: 4),
        pw.Text(_filled(body), style: _body),
      ],
    ),
  );
}

pw.Widget _people({
  required String title,
  required List<BandMember> members,
  required List<pw.Widget> Function(BandMember member) lines,
}) {
  final people = sortedRiderMembers(members);
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title.toUpperCase(), style: _label),
        pw.SizedBox(height: 8),
        if (people.isEmpty)
          pw.Text('Ingen profiler er utfylt ennå.', style: _body)
        else
          for (final member in people) ...[
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line, width: 0.6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    member.name.trim().isEmpty
                        ? 'Uten navn'
                        : member.name.trim(),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    member.role.trim().isEmpty
                        ? 'Rolle ikke satt'
                        : member.role.trim(),
                    style: _small,
                  ),
                  pw.SizedBox(height: 6),
                  ...lines(member),
                ],
              ),
            ),
          ],
      ],
    ),
  );
}

pw.Widget _labeled(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: '$label  ', style: _label),
          pw.TextSpan(text: value, style: _body),
        ],
      ),
    ),
  );
}

pw.Widget _plotGraphic(StagePlot plot) {
  if (plot.isSvg) {
    try {
      return pw.SvgImage(svg: utf8.decode(plot.bytes), fit: pw.BoxFit.contain);
    } catch (_) {
      return pw.Text('SVG-scenekartet kunne ikke tegnes inn.', style: _body);
    }
  }
  if (plot.isRaster) {
    try {
      return pw.Center(
        child: pw.Image(pw.MemoryImage(plot.bytes), fit: pw.BoxFit.contain),
      );
    } catch (_) {
      return pw.Text('Bildet kunne ikke tegnes inn.', style: _body);
    }
  }
  return pw.Text(
    'Filen er en PDF. Originalen kan lastes ned fra rideren i Lávdi Artist.',
    style: _body,
  );
}

pw.ImageProvider? _mark(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

String _filled(String value, {String empty = 'Ikke satt'}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? empty : trimmed;
}

final _body = pw.TextStyle(fontSize: 11, height: 1.35, color: _ink);
final _small = pw.TextStyle(fontSize: 9, color: _muted);
final _label = pw.TextStyle(
  fontSize: 8,
  fontWeight: pw.FontWeight.bold,
  letterSpacing: 0.8,
  color: _muted,
);
