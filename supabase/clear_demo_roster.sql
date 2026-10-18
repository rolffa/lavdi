-- Fjern demomedlemmer, demolåter, invitasjoner og rider-tekst.
-- Bandleder for Rolffa beholdes (tom profil).

delete from public.band_invites;
delete from public.band_members where coalesce(er_leder, false) = false;
delete from public.repertoire;
delete from public.venue_notes where true;

update public.bands
set tech_felles = '',
    hospitality_felles = '',
    input_liste = '',
    monitor = '',
    scenerigg = '',
    pa_krav = '',
    kontaktinfo = coalesce(nullif(btrim(kontaktinfo), ''), 'rolffa@lavdi.no');

update public.band_members
set telefon = '',
    mat = '',
    tech_personlig = ''
where coalesce(er_leder, false);
