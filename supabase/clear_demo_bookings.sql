-- Fjern alle forespørsler, tilbud og gigs (demodata) fra live.
-- Artister/band beholdes. Gigs må slettes før bookings (FK restrict).

delete from public.artist_offers;
delete from public.gigs;
delete from public.bookings;
