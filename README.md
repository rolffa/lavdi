# Lávdi

Booking- og produksjonsportal for artister og arrangører. Flutter Web mot Supabase.

Uten Supabase-nøkler kjører portalen i demomodus. Forespørsler lagres da bare i økten. Produksjonssiden for eksempeljobben ligger på `/production/amundsen-demo-linn`.

## Kjør

```bash
flutter run -d chrome
```

Med Supabase, legg URL og anon-nøkkel i `.env.json` (filen er gitignorert):

```bash
flutter run -d chrome --dart-define-from-file=.env.json
```

## Database

Kjør disse filene i SQL-editoren i Supabase, i denne rekkefølgen:

1. `supabase/schema.sql`
2. `supabase/seed.sql`

Seed er eksempeldata. Bytt `video_url` før lansering, og slett giggen med token `amundsen-demo-linn`. Videolenken i eksempelet er ett fritt konsertklipp som står inne til dere legger inn hver artists eget liveshow på omtrent 30 sekunder. EiGA, Felgen Orkester, Rolffa, R & GM, Kevin Boine og Henning Anti bruker sine egne Spotify-profiler.

### Flyt

1. Arrangør åpner en artist, velger en grønn dato og sender forespørsel.
2. Forespørselen settes inn i `bookings` med status `inquiry`. `bookings.id` er hendelses-ID-en for resten av flyten, og raden har `artist_id`, dato og arrangøropplysningene.
3. Når kontrakten er signert, kjør dette som database-eier (ikke med anon-nøkkelen):

```sql
select confirm_booking('<booking-uuid>');
```

4. Bekreftelsen setter status `confirmed`, oppretter en rad i `gigs` med samme `booking_id`, og setter artistens kalender til opptatt den datoen. En artist kan bare ha én bekreftet jobb per dato.
5. Funksjonen returnerer en `booking_token`. Send arrangøren lenken `/production/<booking_token>`.
6. Produksjonssiden henter artistnavn, dato, spillested og arrangør fra bookingen via `booking_id`. Lagring skriver bare kjøreplanen til `gigs.produksjon` og setter status `ready`.

Har du allerede kjørt en eldre `schema.sql`, kjør `supabase/booking_link.sql` før seed. Artistportalen krever i tillegg `supabase/artist_portal.sql` om den ikke ligger i `schema.sql` du kjørte. Band og rider krever `supabase/bands.sql` om den ikke ligger i `schema.sql` du kjørte. Tilgjengelighetskalenderen krever `supabase/artist_availability.sql` om den ikke ligger i `schema.sql` du kjørte. Rider-PDF og scenekart krever `supabase/rider_pdf.sql` om den ikke ligger i `schema.sql` du kjørte. Tilbud til artister krever `supabase/offers.sql` om den ikke ligger i `schema.sql` du kjørte. Push-varsler krever `supabase/push.sql` om den ikke ligger i `schema.sql` du kjørte. Pressepakke og spillestedslogg krever `supabase/press.sql` om den ikke ligger i `schema.sql` du kjørte. Avtaleflyten med admin, 48-timersvar og arrangørskjema krever `supabase/deals.sql`.

## Artistportal

`/min-side` er mobilvennlig innlogging for artister. E-post og passord, eller magisk lenke via Supabase Auth.

1. Opprett brukeren i Authentication, og slå av åpen registrering.
2. Legg `https://<nettstedet>/min-side` inn som tillatt redirect-URL.
3. Koble brukeren til artisten:

```sql
insert into private.artist_logins (artist_id, auth_user_id)
values ('<artist-uuid>', '<auth.users-uuid>');
```

Innlogget artist ser kommende og tidligere konserter. Kjøreplanen leser `gigs.produksjon` og arrangørfeltene på bookingen. Låtbanken ligger i `repertoire`. Dagen etter en konsert ber forsiden om settliste. Den lagres på `setlists`, koblet til `gig_id`, med `tono_tekst` klar til rapportering.

I demomodus er brukeren `rolffa@lavdi.no` / `lavdi`.

Bandlederen oppretter bandet og inviterer crew med e-post og rolle. Medlemmet åpner `/min-side/invitasjon/<token>` og aktiverer kontoen derfra, uten en manuell ID. Profilen krever navn, rolle/instrument, telefon, mat/allergier og personlige tekniske behov. Kjøreplanen er tidslinje og logistikk. Hospitality-rideren og den tekniske rideren ligger som egne faner på konserten og på produksjonssiden, og kan kopieres derfra. Under Ridere kan bandet laste ned komplett rider, kun teknisk rider eller kun hospitality som PDF. Scenekart (PNG, JPG, SVG eller PDF) lastes opp på den tekniske rideren og lagres i bucket `stage-plots`. PNG, JPG og SVG tegnes inn på siste side. En opplastet PDF får samme side med filnavn, og originalen kan lastes ned ved siden av.

For magisk lenke til crew må nye brukere kunne opprettes via e-postlenke, og `https://<nettstedet>/min-side/invitasjon/**` må være en tillatt redirect. En bruker uten invitasjon eller artistkobling kommer ikke inn i portalen.

Hvert bandmedlem fyller inn sin egen reise under «Reise bestilt» på konserten. Bandleder kan sette et medlem på sidelinjen for den konserten. Når alle aktive medlemmer har huket av, ligger PDF-en klar hos admin.

Kalenderen i artistportalen skriver `artist_availability` for bandet. Uten rad er datoen utilgjengelig. Arrangørsiden leser bare `available`, og datoer med en bekreftet jobb kan ikke bookes.

Artist-appen leser `gigs` for innlogget artist. Feltene i `produksjon` er `arrangementsnavn`, `overnatting_navn`, `overnatting_adresse`, `flyplass`, `reiserute`, `get_in`, `lydprove`, `get_in_show`, `showstart`, `curfew` og `merknader`. Tider er `HH:MM`.

`gigs` er ikke lesbar direkte med anon-nøkkelen. Produksjonssiden bruker funksjonene `get_gig_by_token` og `save_production_plan`, som krever tokenet i lenken.

## Admin-kalender

Ruten `/admin/kalender` er ikke lenket fra forsiden. Der velger du artist og klikker en dato for å veksle mellom ledig og opptatt. Klikket lagres med en gang i `availability`, så neste besøk på artistsiden henter den nye statusen.

PIN-en er passordet. Brukernavnet er `admin` til du endrer det. Logg inn én gang på `/admin`. Samme økt gjelder kalender og tilbud.

```sql
select public.set_admin_pin('en-lang-kode');
```

Kjør også `admin_sign_in` i `supabase/deals.sql` hvis databasen allerede finnes. Da sjekkes brukernavn og passord i databasen. Før den funksjonen finnes, godtas brukernavnet `admin` sammen med PIN-en som passord.

Har du allerede kjørt `schema.sql` før denne funksjonen fantes, kjør `supabase/admin_calendar.sql` først. Anon-nøkkelen kan ikke lese eller skrive kalenderen direkte.

## Tilbud

Den offentlige artistsiden viser ikke pris. Arrangørens forespørsel går bare til `/admin`. Der settes honorar og «Send til artist». Artisten har 48 timer på å svare, og nei krever en begrunnelse. Når artisten sier ja, signerer admin kontrakten og huker av «Bekreftet» etter at arrangøren også har signert. Da blir konserten opprettet, pressepakken gjort klar, og arrangøren får skjulte lenker til reiseskjema og dagskjema. Kjør `supabase/deals.sql` hvis databasen allerede finnes. `/admin/tilbud` kan fortsatt sende et tilbud uten at arrangøren har brukt skjemaet på artistsiden.

## Varsler til bandleder

Bandlederen får e-post, ikke varsel i nettleseren. Min side viser adressen. En arrangørforespørsel varsler ingen. Når admin sender tilbudet til artisten, og klokken 10 i Europe/Oslo for en ubekreftet settliste fra dagen før, skrives en rad i `mail_outbox` til bandlederens e-post fra `auth.users`.

Det finnes ingen mailserver, så radene blir liggende til en avsender er koblet på. Kjør `supabase/mail.sql` hvis databasen allerede finnes.

## Pressepakke og spillestedslogg

Bandmedlemmer redigerer bio og tre pressebilder på `/artist/presse`. Bildene lagres i bucket `press-kits`. Arrangører leser pakken på `/artister/<slug>/presse`, kan kopiere bioen og laste ned bildene. Spotify-lenken kommer fra artistprofilen.

Etter en gjennomført konsert kan bandet lagre erfaringer fra spillestedet på kjøreplanen. Notatene ligger i `venue_notes` og vises automatisk neste gang bandet skal spille på samme sted. Kjør `supabase/press.sql` hvis databasen allerede finnes.
