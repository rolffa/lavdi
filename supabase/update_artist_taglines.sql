-- Musikktype under artistnavn på forsiden (erstatter Duo/Solo/Band).
-- Trygt å kjøre på nytt.

update public.artists set tagline = 'Elektronisk, EDM, joik' where navn = 'EiGA';
update public.artists set tagline = 'Partymusikk' where navn = 'Kevin Boine';
update public.artists set tagline = 'Partyjoik' where navn = 'Rolffa';
update public.artists set tagline = 'Partymusikk' where navn = 'Avskilta';
update public.artists set tagline = 'Klassisk rock' where navn = 'Henning Anti';
update public.artists set tagline = 'Folk rock' where navn = 'Felgen Orkester';
