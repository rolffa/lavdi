import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Data for Lávdi konsertkontrakt (speiler assets/contracts/Lavdi_Konsertkontrakt_Mal.pdf).
class ContractPayload {
  const ContractPayload({
    required this.bookingId,
    required this.artistName,
    required this.date,
    required this.venue,
    this.city = '',
    this.organization = '',
    this.organizerName = '',
    this.orgNumber = '',
    this.contactPerson = '',
    this.email = '',
    this.phone = '',
    this.invoiceAddress = '',
    this.crewNote = '',
    this.soundcheck = '',
    this.showStart = '',
    this.duration = '',
    this.fee,
  });

  final String bookingId;
  final String artistName;
  final DateTime date;
  final String venue;
  final String city;
  final String organization;
  final String organizerName;
  final String orgNumber;
  final String contactPerson;
  final String email;
  final String phone;
  final String invoiceAddress;
  final String crewNote;
  final String soundcheck;
  final String showStart;
  final String duration;
  final int? fee;

  String get party2Name {
    final org = organization.trim();
    if (org.isNotEmpty) return org;
    return organizerName.trim();
  }

  factory ContractPayload.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['dato'];
    final date = dateRaw is DateTime
        ? dateRaw
        : DateTime.tryParse(dateRaw?.toString() ?? '') ?? DateTime.now();
    return ContractPayload(
      bookingId: json['booking_id']?.toString() ?? json['id']?.toString() ?? '',
      artistName: (json['artist_navn'] as String?)?.trim() ?? '',
      date: DateTime(date.year, date.month, date.day),
      venue: (json['spillested'] as String?)?.trim() ?? '',
      city: (json['by'] as String?)?.trim() ?? '',
      organization: (json['organisasjon'] as String?)?.trim() ?? '',
      organizerName: (json['arrangor_navn'] as String?)?.trim() ?? '',
      orgNumber: (json['org_nr'] as String?)?.trim() ?? '',
      contactPerson: (json['kontaktperson'] as String?)?.trim() ?? '',
      email: (json['epost'] as String?)?.trim() ?? '',
      phone: (json['telefon'] as String?)?.trim() ?? '',
      invoiceAddress: (json['fakturaadresse'] as String?)?.trim() ?? '',
      crewNote: (json['reisefolge'] as String?)?.trim() ?? '',
      soundcheck: (json['lydprove'] as String?)?.trim() ??
          (json['oppmote'] as String?)?.trim() ??
          '',
      showStart: (json['showstart'] as String?)?.trim() ?? '',
      duration: (json['varighet'] as String?)?.trim() ?? '',
      fee: json['honorar'] is num ? (json['honorar'] as num).toInt() : null,
    );
  }
}

const _ink = PdfColor.fromInt(0xFF161513);
const _muted = PdfColor.fromInt(0xFF6E6960);
const _line = PdfColor.fromInt(0xFFDDD6C8);

Future<List<int>> buildContractPdf(ContractPayload data) async {
  final doc = pw.Document();
  final dateLabel = DateFormat('d. MMMM yyyy', 'nb').format(data.date);
  final feeLabel = data.fee == null
      ? ''
      : NumberFormat.decimalPattern('nb').format(data.fee);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
      build: (context) => [
        pw.Text(
          'KONSERTKONTRAKT',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Denne avtalen er inngått mellom:',
          style: const pw.TextStyle(fontSize: 11, color: _ink),
        ),
        pw.SizedBox(height: 18),
        _heading('1. AVTALEPARTER'),
        pw.SizedBox(height: 10),
        _subheading('PART 1: Produsent / Management (Oppdragstaker)'),
        pw.SizedBox(height: 6),
        _infoTable([
          ('Firmanavn', 'Amundsen Studio'),
          ('Organisasjonsnummer', '923 934 499'),
          ('Kontaktperson', 'Lisa-Marie Anti / Rolf Amundsen'),
          ('E-post', 'post@amundsenstudio.no'),
          ('Telefon', '46761616 (nød)'),
        ]),
        pw.SizedBox(height: 14),
        _subheading('PART 2: Arrangør (Oppdragsgiver)'),
        pw.SizedBox(height: 6),
        _infoTable([
          ('Arrangør / Selskap', data.party2Name),
          ('Organisasjonsnummer', data.orgNumber),
          ('Kontaktperson', data.contactPerson),
          ('E-post', data.email),
          ('Telefon', data.phone),
          (
            'Fakturaadresse / EHF',
            data.invoiceAddress.isEmpty ? data.email : data.invoiceAddress,
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Text(
          'vedrørende konsertformidling formidlet gjennom Lávdi med:',
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        pw.SizedBox(height: 18),
        _heading('2. ARTIST'),
        pw.SizedBox(height: 6),
        pw.Text(
          'Kontrakten gjelder opptreden med følgende artist/band:',
          style: const pw.TextStyle(fontSize: 10, color: _ink),
        ),
        pw.SizedBox(height: 8),
        _infoTable([
          ('Artist / Band', data.artistName),
          ('Reisefølge (inkl. crew)', data.crewNote),
        ]),
        pw.SizedBox(height: 18),
        _heading('3. KONSERTDETALJER'),
        pw.SizedBox(height: 8),
        _infoTable([
          ('Dato for konsert', dateLabel),
          ('Spillested (Venue)', data.venue),
          ('By / Sted', data.city.isEmpty ? data.venue : data.city),
          ('Oppmøte / Lydprøve', data.soundcheck),
          ('Konsertstart (Showtime)', data.showStart),
          ('Varighet / Spilletid', data.duration),
        ]),
        pw.SizedBox(height: 18),
        _heading('4. HONORAR OG BETALINGSBETINGELSER'),
        pw.SizedBox(height: 8),
        _infoTable([
          ('Avtalt konserthonorar', feeLabel.isEmpty ? '' : 'NOK $feeLabel'),
          (
            'Betalingsfrist',
            '7 dager etter konsertdato (eller ihht. utstedt faktura fra Amundsen Studio).',
          ),
          (
            'Fakturering',
            'Sendes fra Amundsen Studio (Org.nr. 923 934 499) til oppgitt fakturaadresse/EHF.',
          ),
        ]),
        pw.SizedBox(height: 18),
        _heading('5. REISE, LOKAL TRANSPORT, OVERNATTING OG BESPISNING'),
        pw.SizedBox(height: 6),
        _bullet(
          'Reise til nærmeste flyplass: Reise for artist og crew frem til nærmeste flyplass ved konsertstedet er inkludert i det avtalte konserthonoraret, med mindre annet er skriftlig spesifisert.',
        ),
        _bullet(
          'Lokal transport (Ground transport): Arrangør (Part 2) stiller med og dekker all nødvendig lokal transport mellom flyplass, overnattingssted (hotell) og konsertsted ved ankomst, på konsertdagen og ved avreise.',
        ),
        _bullet(
          'Overnatting (Hotell): Arrangør (Part 2) bekoster og booker overnatting av god standard (enkeltrom/dobbeltrom etter avtalt rider) for hele reisefølget.',
        ),
        _bullet(
          'Mat og forpleining: Arrangør (Part 2) står for og dekker fullverdig varm mat og forpleining på konsertdagen (i henhold til hospitality rider), samt frokost dagen etter konserten for hele reisefølget.',
        ),
        pw.SizedBox(height: 14),
        _heading('6. TEKNISK OG HOSPITALITY RIDER'),
        pw.SizedBox(height: 6),
        _bullet(
          'Artistens til enhver tid gjeldende Tekniske Rider og Hospitality Rider (tilgjengelig og nedlastbar via Lávdi på lavdi.no) utgjør en uatskillelig del av denne kontrakten.',
        ),
        _bullet(
          'Arrangør plikter å stille med ferdig opprigget, profesjonelt lyd- og lysutstyr samt kvalifisert teknisk personell i henhold til teknisk rider, med mindre annet er avtalt skriftlig.',
        ),
        _bullet(
          'Eventuelle avvik fra rider må meldes inn og godkjennes av Amundsen Studio i god tid før arrangementet.',
        ),
        pw.SizedBox(height: 14),
        _heading('7. TONO OG OFFENTLIGE AVGIFTER'),
        pw.SizedBox(height: 6),
        _bullet(
          'Arrangør (Part 2) er alene ansvarlig for innrapportering og betaling av vederlag til TONO, samt eventuelle andre offentlige avgifter, tillatelser og gebyrer knyttet til arrangementet.',
        ),
        _bullet(
          'Arrangør forplikter seg til å fylle ut skjema for publikumstall og arrangementsinformasjon i Lávdi etter endt konsert.',
        ),
        pw.SizedBox(height: 14),
        _heading('8. MARKEDSFØRING OG PRESSEMATERIELL'),
        pw.SizedBox(height: 6),
        _bullet(
          'Arrangør skal benytte offisiell biografi og godkjente pressebilder fra artistens pressepakke i Lávdi ved all markedsføring av konserten.',
        ),
        pw.SizedBox(height: 14),
        _heading('9. KANSELLERING OG FORCE MAJEURE'),
        pw.SizedBox(height: 6),
        _bullet(
          'Denne avtalen er bindende for begge parter når konsertforespørselen er godkjent og bekreftet.',
        ),
        _bullet(
          'Ved avlysning fra Arrangørs side som ikke skyldes Force Majeure, plikter Arrangør å betale 100 % av det avtalte honoraret samt dekke eventuelle påløpte dokumenterte utgifter.',
        ),
        _bullet(
          'Dersom konserten må avlyses grunnet Force Majeure (herunder krig, naturkatastrofer, myndighetsbestemte forbud, alvorlig akutt sykdom hos artist dokumentert ved legeerklæring, eller innstilte flyavganger uten alternativ reisemulighet), bortfaller partenes forpliktelser uten erstatningsansvar. Partene skal i slike tilfeller søke å finne ny dato for gjennomføring.',
        ),
        pw.SizedBox(height: 18),
        _heading('10. SIGNATUR (MANUELL SIGNERING)'),
        pw.SizedBox(height: 6),
        pw.Text(
          'Denne kontrakten signeres fysisk/manuelt i to eksemplarer – ett til hver av partene – eller scannes i signert stand.',
          style: const pw.TextStyle(fontSize: 10, color: _ink),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _signatureBlock(
                title: 'Part 1: Produsent / Management',
                forWhom: 'For Amundsen Studio (Org.nr. 923 934 499)',
                nameHint: 'Lisa-Marie Anti / Rolf Amundsen',
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: _signatureBlock(
                title: 'Part 2: Arrangør',
                forWhom:
                    'For ${data.party2Name.isEmpty ? 'Arrangør' : data.party2Name}'
                    '${data.orgNumber.isEmpty ? '' : ' (Org.nr. ${data.orgNumber})'}',
                nameHint: data.contactPerson,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _heading(String text) {
  return pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );
}

pw.Widget _subheading(String text) {
  return pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );
}

pw.Widget _bullet(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 12,
          child: pw.Text('•', style: const pw.TextStyle(fontSize: 10, color: _ink)),
        ),
        pw.Expanded(
          child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5, color: _ink, height: 1.35)),
        ),
      ],
    ),
  );
}

pw.Widget _infoTable(List<(String, String)> rows) {
  return pw.Table(
    border: pw.TableBorder.all(color: _line, width: 0.6),
    columnWidths: {
      0: const pw.FlexColumnWidth(1.1),
      1: const pw.FlexColumnWidth(2),
    },
    children: [
      for (final row in rows)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                row.$1,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(
                row.$2.isEmpty ? '—' : row.$2,
                style: const pw.TextStyle(fontSize: 9.5, color: _ink),
              ),
            ),
          ],
        ),
    ],
  );
}

pw.Widget _signatureBlock({
  required String title,
  required String forWhom,
  required String nameHint,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(forWhom, style: const pw.TextStyle(fontSize: 9, color: _muted)),
      pw.SizedBox(height: 16),
      pw.Text('Sted / Dato: ____________________', style: const pw.TextStyle(fontSize: 9, color: _ink)),
      pw.SizedBox(height: 14),
      pw.Text('Signatur: ____________________', style: const pw.TextStyle(fontSize: 9, color: _ink)),
      pw.SizedBox(height: 14),
      pw.Text(
        'Navn: ${nameHint.isEmpty ? '____________________' : nameHint}',
        style: const pw.TextStyle(fontSize: 9, color: _ink),
      ),
    ],
  );
}
