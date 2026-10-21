-- Kevin Boine: nytt profilbilde, video og bio
update public.artists
set
  bilde_url = 'assets/artist/kevin_profile_2.JPG',
  video_url = 'assets/artist/movie/kevin_movie_1.mp4',
  bio = $bio$Med over 200 millioner streams, har Kevin Boine vokst seg til å bli en av Nord-Norges yndlinger. Den 32 år gamle artisten fra Tana har opparbeidet seg en lojal og stadig voksende fanskare, og spiller festivaler over hele Skandinavia. Som en av svært få i sin sjanger krysser han landegrenser og forener folk med sin fengende og folkelige stil.$bio$
where navn = 'Kevin Boine';
