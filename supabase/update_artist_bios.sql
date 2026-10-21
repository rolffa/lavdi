-- Oppdater artist-bioer: EiGA fra content/bios, fjern rider-setning på alle.
update public.artists
set bio = $bio$EiGA er en samisk joike- og elektronika-duo som springer ut fra Máze i Sápmi. Duoen består av joikerne og artistene Johan Ivvar Gaup og Piera Eira. Sistnevnte vant sangdelen i Sámi Grand Prix i 2025 sammen med MÁIJÁ med låten «Dálkkiid Čađa».

EiGA er kjent for å forene tradisjonell joik med moderne EDM- og elektronika-elementer, noe som skaper et unikt og energisk lydbilde som har fått stor oppmerksomhet på festivaler og arrangementer. Duoen har gitt ut utgivelser som låten «Duinna» (gjestet av Elin Oskal) og singelen «Muittašan» (gjestet av MÁIJÁ).

Eiga passer like godt til klubbscener som til store festivaler.$bio$
where navn = 'EiGA';

update public.artists
set bio = 'Felgen Orkester bookes til klubber, kulturhus og festivaler.'
where navn = 'Felgen Orkester';

update public.artists
set bio = 'Rolffa bookes til klubber, kulturhus og festivaler.'
where navn = 'Rolffa';

update public.artists
set bio = 'Avskilta er en duo som bookes til klubber, kulturhus og festivaler.'
where navn in ('Avskilta', 'R & GM');

update public.artists
set bio = $bio$Med over 200 millioner streams, har Kevin Boine vokst seg til å bli en av Nord-Norges yndlinger. Den 32 år gamle artisten fra Tana har opparbeidet seg en lojal og stadig voksende fanskare, og spiller festivaler over hele Skandinavia. Som en av svært få i sin sjanger krysser han landegrenser og forener folk med sin fengende og folkelige stil.$bio$
where navn = 'Kevin Boine';

update public.artists
set bio = 'Henning Anti bookes til klubber, kulturhus og festivaler.'
where navn = 'Henning Anti';
