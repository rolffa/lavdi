-- R & GM → Avskilta + nytt forsidesbilde
update public.artists
set
  navn = 'Avskilta',
  bio = replace(coalesce(bio, ''), 'R & GM', 'Avskilta'),
  bilde_url = 'assets/artist/Avskilta_full_rust.jpg'
where navn = 'R & GM'
   or bilde_url like '%roggm_profile_1%';

update public.bands
set navn = 'Avskilta'
where navn = 'R & GM'
   or artist_id in (
     select id from public.artists where navn = 'Avskilta'
   );
