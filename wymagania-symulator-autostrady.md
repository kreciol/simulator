# Symulator jazdy autostradą: dokument wymagań (MVP)

> Wersja: 0.1 · Status: wymagania zebrane, część parametrów do strojenia
> Stack: Godot 4.x · GDScript · eksport Web (WebAssembly + WebGL 2)
> Kod generowany przy wsparciu Claude Code

---

## 0. Konwencje dokumentu

- **[DECYZJA]** oznacza wymaganie uzgodnione, do implementacji bez zmian.
- **[PROPOZYCJA]** oznacza wartość domyślną lub rozwiązanie zaproponowane podczas analizy. Do implementacji, ale może zostać zmienione.
- **[PARAM]** oznacza wartość liczbową, którą trzeba wystawić w konfiguracji (nie hardkodować) i stroić po testach.
- **[OTWARTE]** oznacza kwestię nierozstrzygniętą. Zaimplementować wariant domyślny i oznaczyć w kodzie `# TODO(open):`.
- Słowa **MUSI / POWINIEN / MOŻE** mają znaczenie jak w RFC 2119.

---

## 1. Cel produktu

### 1.1 Problem
Wielu kierowców, szczególnie niedoświadczonych, ma złe nawyki na drogach szybkiego ruchu:
- zbyt długo zajmuje lewy pas, mimo że prawy jest wolny,
- zmienia pas bez kierunkowskazu lub sygnalizuje za późno,
- nie zachowuje bezpiecznego odstępu od poprzedzającego pojazdu.

Na kursie prawa jazdy autostrada praktycznie nie występuje, więc te nawyki nie są nigdzie ćwiczone.

### 1.2 Cel
Lekka gra-symulator w przeglądarce, która w krótkich sesjach uczy prawidłowej jazdy autostradą i drogą ekspresową zgodnie z polskimi przepisami. Daje użytkownikowi ocenę punktową oraz słowną informację zwrotną.

### 1.3 Grupa docelowa [DECYZJA]
Osoby z **małym doświadczeniem za kierownicą**, które **chcą podnieść swoje umiejętności**: świeżo po egzaminie, przed pierwszą dłuższą trasą, kursanci.

Konsekwencje projektowe:
- ton komunikatów **wspierający**, nie karzący,
- komunikaty **wyjaśniają regułę** (dlaczego), a nie tylko wskazują błąd,
- łagodna krzywa trudności, a pierwszy kontakt bez presji.

### 1.4 Benchmark
Najbliższy istniejący produkt to **LeftLane** (leftlane.online): przeglądarkowy symulator z widokiem z kabiny, krótkie oceniane scenariusze z coachingiem. Różnice względem tego projektu:
- ten projekt skupia się wyłącznie na autostradzie i ekspresówce,
- stosuje polskie przepisy,
- ma dwa tryby (nauka i egzamin),
- trudność regulowana jest natężeniem ruchu.

---

## 2. Zakres

### 2.1 W zakresie MVP
- jazda w dzień, przy dobrej pogodzie,
- prosta, nieskończona droga dwujezdniowa (bez zakrętów, wzniesień i węzłów),
- dwa profile drogi: autostrada i droga ekspresowa,
- ruch innych pojazdów (AI poziom „średni”),
- dwa tryby gry: nauka (asysta) i egzamin,
- system punktowy z karami i nagrodami,
- słowna informacja zwrotna,
- poziomy trudności oparte na natężeniu ruchu,
- lokalny zapis wyników i historii,
- samouczek [PROPOZYCJA].

### 2.2 Poza zakresem MVP (planowane rozszerzenia)
- jazda w nocy,
- trudne warunki pogodowe (deszcz, mgła, śnieg),
- węzły: wjazdy, zjazdy, pasy rozbiegowe i włączania,
- zakręty i ukształtowanie terenu,
- AI reagujące na gracza (ustępowanie, wpuszczanie, zajeżdżanie drogi),
- dźwięki i komunikaty głosowe,
- kierownica, pedały i kontroler,
- konta użytkowników i synchronizacja wyników między urządzeniami,
- obsługa urządzeń mobilnych i dotyku.

---

## 3. Platforma i technologia

### 3.1 Platforma [DECYZJA]
- Aplikacja **uruchamiana w przeglądarce** na komputerze (desktop).
- Brak instalacji i brak rejestracji.
- Wspierane przeglądarki: aktualne Chrome, Edge, Firefox. Safari [POWINIEN].

### 3.2 Stack [DECYZJA]
- Silnik: **Godot 4.x** (konkretną wersję zapisać w `project.godot` i README).
- Język: **GDScript** z **pełnym statycznym typowaniem** (`var speed: float`, typowane sygnatury funkcji).
- Eksport: **Web** (HTML5 / WebAssembly).

### 3.3 Ograniczenia techniczne platformy web [DECYZJA]
- Renderer: **Compatibility** (WebGL 2), ustawiony od początku projektu. Nie używać funkcji dostępnych tylko w Forward+ / Mobile.
- Eksport **jednowątkowy** (bez wymogu nagłówków COOP/COEP / `SharedArrayBuffer`).
- Zapis danych przez `user://`, który w przeglądarce trafia do IndexedDB.
- Budżet rozmiaru [PARAM]: łączny rozmiar paczki POWINIEN być jak najmniejszy, cel ≤ 50 MB. Assety (modele, tekstury) low-poly, tekstury skompresowane.
- Wydajność [PARAM]: cel 60 FPS na typowym laptopie ze zintegrowaną grafiką, minimum akceptowalne 30 FPS.

### 3.4 Hosting i CI/CD [PROPOZYCJA]
- Statyczny hosting (np. Azure Static Web Apps lub GitHub Pages).
- Pipeline GitHub Actions: eksport headless Godota, potem deploy przy pushu na `main`.
- Repozytorium Git. Sceny (`.tscn`) i zasoby (`.tres`) w formacie tekstowym.

---

## 4. Świat gry: droga

### 4.1 Profile drogi [DECYZJA]
Typ drogi to parametr sesji, który determinuje limit prędkości i liczbę pasów.

| Profil | Limit prędkości | Pasy w jednym kierunku |
|---|---|---|
| Autostrada | 140 km/h | 2 [PARAM], opcjonalnie 3 |
| Droga ekspresowa | 120 km/h | 2 [PARAM] |

- Profile MUSZĄ być zdefiniowane jako zasoby danych (`Resource` / `.tres`), a nie w kodzie.
- Pola profilu: `id`, `display_name`, `speed_limit_kmh`, `lane_count`, `lane_width_m` [PARAM, domyślnie 3.75], `shoulder_width_m` [PARAM].

### 4.2 Geometria [DECYZJA]
- Droga **dwujezdniowa**: jezdnia gracza oraz jezdnia przeciwna oddzielona pasem rozdziału lub barierą.
- Ruch na jezdni przeciwnej: czysto dekoracyjny [PROPOZYCJA], nie bierze udziału w logice.
- Droga **prosta, nieskończona**.
- Elementy wizualne: linie przerywane między pasami, linie krawędziowe ciągłe, pobocze (pas awaryjny), bariery, prosty teren lub tło.

### 4.3 Realizacja nieskończonej drogi [PROPOZYCJA]
- Droga zbudowana z powtarzalnych segmentów (np. N segmentów po L m [PARAM]). Segment znikający za graczem jest przenoszony na przód (recykling, object pooling).
- Pozycja gracza w świecie renderowanym pozostaje bliska zera (*floating origin*), aby uniknąć błędów precyzji float przy długich dystansach.
- **Logika symulacji MUSI być oddzielona od renderowania** (patrz 11.2): symulacja operuje na współrzędnych logicznych (pozycja wzdłużna `s` w metrach, numer pasa / pozycja poprzeczna), a warstwa wizualna tylko je odwzorowuje.

---

## 5. Pojazd gracza

### 5.1 Widok [DECYZJA]
- Kamera **z perspektywy kierowcy (z kabiny)**, scena 3D.
- Widoczne: fragment deski rozdzielczej lub maski, droga przed pojazdem.

### 5.2 Widoczność otoczenia [DECYZJA]
Gracz MUSI mieć możliwość oceny ruchu z tyłu i z boków:
- **lusterko wsteczne** (środkowe),
- **lusterka boczne** (lewe i prawe).

[PROPOZYCJA] Implementacja lusterek przez `SubViewport` z obniżoną rozdzielczością i rzadszą aktualizacją. Na webie to kosztowne, więc potrzebny przełącznik jakości.

[OTWARTE] Czy w trybie nauki pokazywać dodatkowy wskaźnik martwego pola (ikona przy lusterku)? Proponowany wariant domyślny: tak w trybie nauki, nie w trybie egzaminu.

### 5.3 Elementy HUD [PROPOZYCJA]
- prędkościomierz (km/h),
- aktualny limit prędkości,
- stan kierunkowskazu (strzałki migające),
- pozostały czas sesji,
- bieżący wynik punktowy (w trybie nauki; w egzaminie [OTWARTE], domyślnie ukryty),
- obszar komunikatów (tryb nauki).

### 5.4 Model jazdy [PROPOZYCJA]
- Uproszczony, arkadowy: przyspieszenie i hamowanie ze stałymi lub zależnymi od prędkości wartościami [PARAM].
- Brak symulacji skrzyni biegów, sprzęgła i fizyki opon.
- Prędkość minimalna 0, maksymalna [PARAM] (np. 180 km/h). Gracz MOŻE przekroczyć limit, patrz [OTWARTE] 8.5.

---

## 6. Akcje użytkownika i sterowanie

### 6.1 Akcje [DECYZJA]
1. **Przyspieszanie**
2. **Zwalnianie / hamowanie**
3. **Zmiana pasa w lewo**
4. **Zmiana pasa w prawo**
5. **Włączenie / wyłączenie kierunkowskazu lewego**
6. **Włączenie / wyłączenie kierunkowskazu prawego**

### 6.2 Urządzenie wejściowe [DECYZJA]
**Klawiatura.**

### 6.3 Mapowanie klawiszy [PROPOZYCJA]
Zdefiniowane w Input Map Godota, aby można je było zmienić bez zmian w kodzie.

| Akcja | Klawisz główny | Alternatywny |
|---|---|---|
| Przyspiesz | `W` | `↑` |
| Zwolnij / hamuj | `S` | `↓` |
| Zmiana pasa w lewo | `A` | `←` |
| Zmiana pasa w prawo | `D` | `→` |
| Kierunkowskaz lewy (przełącz) | `Q` | `,` |
| Kierunkowskaz prawy (przełącz) | `E` | `.` |
| Pauza / menu | `Esc` | `P` |

### 6.4 Zmiana pasa [PROPOZYCJA]
- Zmiana pasa jest **dyskretną, animowaną akcją**: naciśnięcie przesuwa pojazd płynnie na sąsiedni pas w czasie [PARAM] ≈ 1,5–2 s.
- Próba zmiany pasa poza skrajny pas jezdni oznacza **zjechanie z drogi** (patrz 9.2).
- [OTWARTE] Alternatywa: ciągłe sterowanie poprzeczne. Wariant dyskretny jest preferowany na MVP ze względu na prostotę i czytelność oceny.

### 6.5 Kierunkowskaz [DECYZJA]
- Kierunkowskaz **nie jest wymagany** do wykonania manewru: manewr zawsze się wykona.
- Brak kierunkowskazu **obniża ocenę** (patrz 8.2).
- [PROPOZYCJA] Kierunkowskaz wyłącza się automatycznie po zakończeniu zmiany pasa (jak samopowrót przy kierownicy).
- [PROPOZYCJA] Kierunkowskaz uznaje się za prawidłowy, jeśli był włączony w odpowiednim kierunku przez co najmniej [PARAM] 1,0 s przed rozpoczęciem zmiany pasa.

---

## 7. Ruch innych pojazdów (AI)

### 7.1 Poziom zachowania [DECYZJA]
Poziom **„średni”**:
- każdy pojazd ma własną prędkość docelową (losowaną z rozkładu [PARAM], np. 90–150 km/h zależnie od profilu drogi; część pojazdów to wolniejsze ciężarówki ≈ 80–90 km/h [PROPOZYCJA]),
- pojazdy **same wyprzedzają wolniejszych** i **wracają na prawy pas** po wyprzedzeniu,
- pojazdy **nie reagują specjalnie na gracza** (bez ustępowania i zajeżdżania drogi). Muszą jednak unikać najechania na gracza (hamują przed nim jak przed każdym innym pojazdem).

### 7.2 Wymagania na logikę AI [PROPOZYCJA]
- Pojazdy AI stosują **tę samą funkcję oceny wolnego pasa** co system oceniania gracza (współdzielony kod, patrz 8.4).
- Pojazdy AI utrzymują odstęp ≥ połowa prędkości (wzorowi kierowcy) [PARAM: współczynnik „dyscypliny”, by część AI jeździła mniej wzorowo na wyższych poziomach].
- Pojazdy AI używają kierunkowskazów (wizualnie) przed zmianą pasa. To też element nauki obserwacji.
- Prosty model car-following (np. IDM, Intelligent Driver Model) oraz decyzja o zmianie pasa oparta na korzyści prędkości i bezpieczeństwie luki (np. uproszczony MOBIL).

### 7.3 Generowanie i usuwanie pojazdów [PROPOZYCJA]
- Pojazdy pojawiają się poza zasięgiem widoku (przed i za graczem) i są usuwane po oddaleniu się o [PARAM] m.
- Gęstość ruchu (pojazdy/km/pas) zależy od poziomu trudności (patrz 10).
- Spawn MUSI gwarantować, że pojazd nie pojawi się w kolizji ani w niebezpiecznej odległości od gracza.
- Pula obiektów (object pooling) zamiast tworzenia i niszczenia węzłów.

### 7.4 Wygląd [PROPOZYCJA]
- Kilka typów low-poly: osobowy, SUV/van, ciężarówka; różne kolory.
- Działające światła stopu i kierunkowskazy.

---

## 8. System oceniania

### 8.1 Zasady ogólne [DECYZJA]
- Ten sam system punktowy działa **w obu trybach**. Tryby różnią się tylko sposobem prezentacji (patrz 9).
- Każde oceniane zdarzenie jest zapisywane w **dzienniku zdarzeń sesji** (patrz 8.6). Na jego podstawie powstaje informacja zwrotna w obu trybach.
- Każda kara ma swój lustrzany odpowiednik po stronie nagród.

### 8.2 Kary (punkty w dół) [DECYZJA]

#### K1. Za mały odstęp od poprzedzającego pojazdu
- Podstawa prawna: **art. 19 ust. 3 pkt 2 ustawy Prawo o ruchu drogowym** (od 1.06.2021): na autostradzie i drodze ekspresowej odstęp w metrach nie mniejszy niż **połowa prędkości w km/h**.
- `min_gap_m = speed_kmh / 2`
- Przepis **nie dotyczy wyprzedzania**, więc kara nie jest naliczana w trakcie manewru wyprzedzania (definicja w 8.4).
- **Kara stopniowana**: im mniejszy odstęp, tym większa kara.
- [PROPOZYCJA] Funkcja kary naliczana w sposób ciągły (na sekundę):
  - `ratio = gap / min_gap`
  - `ratio ≥ 1.0` → brak kary
  - `ratio < 1.0` → `penalty_per_s = K1_BASE * (1 - ratio)^EXP`
  - [PARAM] `K1_BASE`, `EXP` (≥ 1; `EXP = 2` daje karę rosnącą coraz ostrzej przy zbliżaniu się)
  - [OTWARTE] liniowo czy nieliniowo; domyślnie nieliniowo (`EXP = 2`).
- Odstęp mierzony od przodu pojazdu gracza do tyłu pojazdu poprzedzającego **na tym samym pasie**.

#### K2. Jazda lewym pasem, gdy prawy jest wolny
- Kara naliczana, gdy gracz jest na pasie innym niż skrajny prawy, a pas po jego prawej jest wolny (definicja w 8.4).
- **Okres karencji** [PARAM, domyślnie 3–5 s]: kara nie jest naliczana od razu. Gracz ma czas na powrót, np. tuż po wyprzedzeniu.
- W trybie nauki w trakcie karencji wyświetla się podpowiedź „wróć na prawy pas”.
- Po upływie karencji kara naliczana w sposób ciągły [PARAM, punkty/s].
- Nie dotyczy sytuacji, w której gracz jest w trakcie wyprzedzania (pojazd wyprzedzany jest wciąż przed nim lub obok niego na pasie po prawej).

#### K3. Zmiana pasa bez kierunkowskazu
- Kara jednorazowa [PARAM] za każdą zmianę pasa bez prawidłowego kierunkowskazu.
- [PROPOZYCJA] Rozróżnienie:
  - brak kierunkowskazu → pełna kara,
  - kierunkowskaz włączony za późno (< min. czas z 6.5) → połowa kary,
  - kierunkowskaz w złą stronę → pełna kara.

#### K4. Kolizja / zjechanie z drogi
- Patrz 9.2. W trybie nauki duża kara jednorazowa [PARAM]. W trybie egzaminu przerwanie sesji.

### 8.3 Nagrody (punkty w górę) [DECYZJA]

#### N1. Poprawna zmiana pasa
- Nagroda jednorazowa [PARAM] za zmianę pasa:
  - z prawidłowym kierunkowskazem (6.5),
  - na pas wolny (bez wymuszenia hamowania innych pojazdów, [PARAM] próg luki),
  - **uzasadniona**: w lewo w celu wyprzedzenia wolniejszego pojazdu lub w prawo w celu powrotu na wolny prawy pas.
- **Zabezpieczenie przed farmieniem punktów** [PROPOZYCJA]:
  - zmiana w lewo bez celu wyprzedzania → brak nagrody (i ewentualnie K2),
  - limit / cooldown nagród za zmiany pasa [PARAM],
  - wartość N1 zbalansowana względem nagród ciągłych N2 i N3.

#### N2. Prawidłowe wykorzystanie prawego pasa
- Nagroda ciągła [PARAM, punkty/s] za jazdę skrajnym prawym pasem, gdy nie ma potrzeby wyprzedzania.

#### N3. Utrzymywanie poprawnej odległości
- Nagroda ciągła [PARAM, punkty/s], gdy `gap ≥ min_gap` (lub brak pojazdu przed graczem w zasięgu [PARAM]).
- [OTWARTE] Czy nagradzać brak pojazdu w zasięgu tak samo jak aktywne utrzymywanie odstępu. Domyślnie: pełna nagroda tylko przy aktywnym podążaniu za pojazdem, mniejsza przy pustej drodze.

### 8.4 Definicje logiczne (współdzielone przez ocenianie, podpowiedzi i AI) [PROPOZYCJA]

Moduł czystej logiki, bez zależności od scen i renderingu, w pełni testowalny jednostkowo.

- **`is_lane_free(lane, s_position, speed, look_ahead_m, look_behind_m) -> bool`**
  Pas jest wolny, jeśli w przedziale `[s - look_behind_m, s + look_ahead_m]` nie ma pojazdu.
  - `look_ahead_m` [PARAM]: dystans, w którym powrót nie zmusiłby do kolejnego wyprzedzania (np. funkcja różnicy prędkości × [PARAM] 8–10 s).
  - `look_behind_m` [PARAM]: bezpieczna luka z tyłu, zależna od prędkości pojazdów nadjeżdżających.
- **`gap_to_leader(vehicle) -> float`**: odstęp do najbliższego pojazdu przed, na tym samym pasie.
- **`min_gap(speed_kmh) -> float`**: `speed_kmh / 2`.
- **`is_overtaking(vehicle) -> bool`**: pojazd jest na pasie lewszym niż skrajny prawy, a na pasie po prawej znajduje się wolniejszy pojazd w przedziale [PARAM] przed / obok niego, lub pojazd jest w trakcie animacji zmiany pasa w lewo.
- **`signal_valid(direction, signal_state, signal_on_time) -> enum {OK, LATE, NONE, WRONG}`**

### 8.5 Kwestie otwarte w ocenianiu
- [OTWARTE] **Przekroczenie prędkości**: czy karać jazdę powyżej limitu? Nie było to uzgodnione, ale jest naturalnym elementem. Proponowany wariant domyślny: kara ciągła powyżej limitu + tolerancja [PARAM], wyłączalna flagą konfiguracyjną.
- [OTWARTE] **Wyprzedzanie z prawej strony**: czy wykrywać i karać.
- [OTWARTE] Czy wynik może być ujemny (domyślnie: nie, minimum 0).

### 8.6 Dziennik zdarzeń sesji [PROPOZYCJA]
Każde zdarzenie oceniane zapisywane jako rekord:

```gdscript
class_name ScoreEvent
var timestamp_s: float        # czas od startu sesji
var type: StringName          # np. &"gap_too_small", &"lane_change_ok", &"no_signal"
var category: StringName      # &"gap", &"lane", &"signal", &"collision"
var points: float             # +/- (dla ciągłych: suma za odcinek)
var context: Dictionary       # np. {speed_kmh, gap_m, min_gap_m, lane_from, lane_to}
```

- Zdarzenia ciągłe (K1, K2, N2, N3) agregowane w **odcinki** (start, koniec, suma punktów, wartość skrajna, np. najmniejszy odstęp), a nie zapisywane co klatkę.
- Dziennik jest źródłem dla komunikatów bieżących (tryb nauki) oraz podsumowania (oba tryby).

---

## 9. Tryby gry i sesja

### 9.1 Tryby [DECYZJA]

| Cecha | Tryb nauki (z asystą) | Tryb egzaminu (bez asysty) |
|---|---|---|
| Podpowiedzi na bieżąco | Tak | Nie |
| Komunikaty o zdarzeniach na bieżąco | Tak | Nie |
| Punktacja w tle | Tak | Tak |
| Podsumowanie słowne na końcu | Tak | Tak |
| Kolizja / zjazd z drogi | Powrót na drogę, kara | Przerwanie sesji |
| Wskaźnik martwego pola | Tak [OTWARTE] | Nie [OTWARTE] |

[PROPOZYCJA] Tryb nauki jest domyślnie wybrany dla nowego użytkownika. Tryb egzaminu jest dostępny zawsze, ale sugerowany po [PARAM] 3 ukończonych sesjach nauki.

### 9.2 Kolizje i zjechanie z drogi [DECYZJA]
- **Kolizja**: kontakt z innym pojazdem (kolizja AABB / kształtów uproszczonych w logice).
- **Zjechanie z drogi**: wyjście poza krawędź jezdni (np. zmiana pasa poza skrajny pas).
- **Tryb egzaminu**: natychmiastowe zakończenie sesji z wynikiem „niezaliczony”, potem ekran podsumowania z przyczyną.
- **Tryb nauki**: komunikat, kara K4, krótka pauza lub fade, a następnie **przywrócenie gracza na drogę** (bezpieczna pozycja na prawym pasie, wolny odcinek przed i za, prędkość [PARAM]). Sesja trwa dalej, a czas sesji nie jest resetowany.

### 9.3 Długość sesji [DECYZJA]
- Sesja ograniczona czasem: **90 sekund** [PARAM].
- Odliczanie startuje po krótkim wprowadzeniu (np. odliczanie 3-2-1), a gracz startuje z prędkością [PARAM] (np. 100 km/h) na prawym pasie.
- Pauza (`Esc`) zatrzymuje czas sesji.

### 9.4 Przepływ aplikacji [PROPOZYCJA]

```
Ekran startowy
 ├─ Samouczek (przy pierwszym uruchomieniu sugerowany)
 ├─ Nowa sesja → wybór: tryb · profil drogi · poziom trudności → Jazda → Podsumowanie
 ├─ Historia wyników
 └─ Ustawienia (jakość grafiki, lusterka, klawiszologia – podgląd)
```

---

## 10. Poziomy trudności [DECYZJA]

- Wyznacznikiem trudności jest **natężenie ruchu**: im wyższy poziom, tym więcej pojazdów.
- [PROPOZYCJA] Poziomy jako zasoby `.tres`:

| Poziom | Gęstość [PARAM] | Uwagi [PROPOZYCJA] |
|---|---|---|
| 1. Spokojnie | bardzo mała | dużo wolnego prawego pasa, AI wzorowe |
| 2. Umiarkowanie | mała–średnia | pierwsze sytuacje wyprzedzania |
| 3. Ruchliwie | średnia | częste wyprzedzanie, więcej ciężarówek |
| 4. Godziny szczytu | duża | ciasne luki, trudny powrót na prawy pas |

- [OTWARTE] Czy wyższe poziomy mają też zwiększać rozrzut prędkości AI i obniżać „dyscyplinę” AI. Domyślnie: tak, umiarkowanie.
- [OTWARTE] Czy poziomy są odblokowywane progresywnie, czy dostępne od razu. Domyślnie: dostępne od razu, z oznaczeniem rekomendowanego.

---

## 11. Informacja zwrotna

### 11.1 Forma [DECYZJA]
- Wynik punktowy **oraz** krótki **opis słowny**, w obu trybach.
- Forma prezentacji (tekst, ikony, dźwięk, głos): [OTWARTE], odłożona. Na MVP **tekst na ekranie + proste ikony** [PROPOZYCJA].

### 11.2 Tryb nauki: na bieżąco
- **Podpowiedź prewencyjna** (zanim pojawi się kara), np. w okresie karencji K2: „Prawy pas jest wolny, wróć na prawo”.
- **Komunikat o zdarzeniu** (po fakcie), np. „Dobrze, kierunkowskaz włączony na czas” / „Zmiana pasa bez kierunkowskazu”.
- Komunikaty **wyjaśniają regułę** [PROPOZYCJA], np. „Za blisko. Przy 120 km/h minimum to 60 m, masz 35 m”.
- Ograniczenie częstotliwości: ten sam typ komunikatu nie częściej niż co [PARAM] s, maksymalnie [PARAM] komunikaty naraz na ekranie.
- Ton: wspierający, krótki, bez wykrzykników karzących.

### 11.3 Podsumowanie po sesji (oba tryby)
- Wynik łączny + wynik w kategoriach: **odstęp**, **pas**, **kierunkowskaz** [PROPOZYCJA].
- Status: ukończona / przerwana (kolizja, zjazd z drogi) / zaliczona lub niezaliczona w egzaminie [OTWARTE: próg zaliczenia, PARAM].
- **Opis słowny 2–4 zdania**, generowany z dziennika zdarzeń, np.:
  > „Jechałeś pewnie i dobrze trzymałeś odstęp. Po wyprzedzaniu dwa razy zostałeś na lewym pasie dłużej niż 5 sekund. Pamiętaj, żeby wracać na prawo, gdy tylko jest wolny. Jedna zmiana pasa była bez kierunkowskazu.”
- [PROPOZYCJA] Generowanie opisu oparte na regułach i szablonach (bez zewnętrznego API): wybór 1 mocnej strony + 1–2 najważniejszych obszarów do poprawy wg sumy kar w kategorii.
- **Wskazówka na następny raz**: jeden konkretny nawyk do ćwiczenia.
- Porównanie z poprzednim wynikiem / rekordem dla tej samej kombinacji (tryb, profil, poziom).

---

## 12. Samouczek [PROPOZYCJA]

- Krótki przejazd **bez ruchu i bez oceny**, sugerowany przy pierwszym uruchomieniu.
- Kroki: przyspiesz → zwolnij → włącz kierunkowskaz → zmień pas → wróć na prawy → spójrz w lusterka.
- Na końcu krótkie przypomnienie 3 zasad: prawy pas, kierunkowskaz, odstęp = połowa prędkości.
- Możliwość pominięcia i ponownego uruchomienia z menu.

---

## 13. Zapis wyników i historia [DECYZJA]

- Wyniki zapisywane lokalnie (`user://` → IndexedDB w przeglądarce).
- Cel: motywacja do powtarzania i poprawiania wyników.
- [PROPOZYCJA] Zapisywane dane sesji:

```json
{
  "schema_version": 1,
  "id": "uuid",
  "started_at": "ISO-8601",
  "mode": "learn | exam",
  "road_profile": "motorway | expressway",
  "difficulty": 1,
  "duration_s": 90,
  "status": "completed | aborted_collision | aborted_offroad",
  "score_total": 0,
  "score_by_category": { "gap": 0, "lane": 0, "signal": 0 },
  "stats": {
    "lane_changes": 0,
    "lane_changes_signaled": 0,
    "time_left_lane_unjustified_s": 0,
    "time_gap_below_min_s": 0,
    "min_gap_ratio": 1.0
  }
}
```

- Ekran historii: lista ostatnich sesji, rekordy per kombinacja (tryb × profil × poziom), prosty wykres trendu wyniku [PROPOZYCJA].
- Pole `schema_version` wymagane, aby umożliwić migrację formatu w przyszłości.
- Ograniczenie liczby zapisanych sesji [PARAM] (np. ostatnie 200).
- Świadomość ograniczenia: dane są przypisane do przeglądarki i urządzenia (wyczyszczenie danych przeglądarki je usuwa). Należy to krótko zakomunikować w UI.

---

## 14. Wymagania niefunkcjonalne

| Obszar | Wymaganie |
|---|---|
| Wydajność | 60 FPS cel / 30 FPS minimum na laptopie ze zintegrowaną grafiką |
| Czas ładowania | Pierwsze uruchomienie [PARAM] ≤ 10 s na łączu 50 Mb/s |
| Rozdzielczość | Skalowanie do okna przeglądarki, min. 1280×720, tryb pełnoekranowy |
| Jakość | Ustawienie jakości (niska / wysoka): rozdzielczość lusterek, cienie, odległość rysowania |
| Determinizm | Symulacja w `_physics_process` ze stałym krokiem; generator losowy z ziarnem (seed) zapisywanym w sesji, co umożliwia odtwarzanie i debugowanie |
| Testowalność | Logika (8.4, ocenianie, AI decyzje) w czystych klasach GDScript bez zależności od scen, pokryta testami jednostkowymi (np. GUT lub gdUnit4) |
| Konfigurowalność | Wszystkie [PARAM] w zasobach `.tres` lub jednym pliku konfiguracyjnym, nie w kodzie |
| Język UI | Polski; teksty w plikach tłumaczeń (Godot `TranslationServer` / CSV), aby umożliwić dodanie innych języków |
| Dostępność | Czytelne fonty, kontrast, komunikaty nie tylko kolorem (ikona + tekst) |
| Prywatność | Brak zbierania danych osobowych, brak kont, brak zewnętrznej telemetrii w MVP |

---

## 15. Proponowana architektura (Godot)

### 15.1 Struktura katalogów [PROPOZYCJA]

```
res://
├─ config/
│  ├─ road_profiles/        # motorway.tres, expressway.tres
│  ├─ difficulty/           # level_1.tres … level_4.tres
│  └─ scoring.tres          # wszystkie wagi i progi oceny
├─ core/                    # czysta logika, bez scen
│  ├─ sim/                  # TrafficSim, VehicleState, LaneQuery (8.4)
│  ├─ ai/                   # car-following, decyzje o zmianie pasa
│  ├─ scoring/              # ScoringSystem, ScoreEvent, EventLog
│  └─ feedback/             # generator komunikatów i podsumowań
├─ game/
│  ├─ session/              # SessionManager (czas, tryb, stan)
│  ├─ player/               # PlayerController, kamera, kierunkowskazy
│  ├─ world/                # RoadBuilder, recykling segmentów, floating origin
│  ├─ traffic/              # VehicleView (wizualizacja stanów z sim), pooling
│  └─ mirrors/              # SubViewporty lusterek
├─ ui/                      # HUD, menu, podsumowanie, historia, samouczek
├─ persistence/             # SaveManager (user://, schema_version)
├─ assets/                  # modele, tekstury, fonty
└─ tests/                   # testy jednostkowe logiki
```

### 15.2 Zasady architektoniczne [PROPOZYCJA]
1. **Rozdzielenie symulacji i prezentacji.** `core/sim` trzyma stan wszystkich pojazdów (pozycja `s`, pas, prędkość, stan zmiany pasa, kierunkowskaz). Warstwa `game/` tylko go czyta i renderuje.
2. **Gracz jest pojazdem w tej samej symulacji** co AI (ten sam `VehicleState`), różni się tylko źródłem decyzji (input zamiast AI).
3. **Ocenianie obserwuje symulację** (czyta stan po każdym kroku), nie modyfikuje jej.
4. **Komunikacja przez sygnały** Godota (`lane_change_started`, `lane_change_finished`, `collision`, `score_event_emitted`, `session_ended`).
5. **Autoloady tylko dla usług globalnych**: `Config`, `SaveManager`, ewentualnie `EventBus`.

---

## 16. Kryteria akceptacji MVP

### Droga i świat
- [ ] Wybór profilu „autostrada” ustawia limit 140 km/h i właściwą liczbę pasów; „ekspresowa” ustawia 120 km/h.
- [ ] Droga renderuje się bez przerw przez całą sesję; brak widocznego „doskakiwania” segmentów.
- [ ] Jezdnia przeciwna jest widoczna i oddzielona.

### Gracz
- [ ] Widok z kabiny; działają 3 lusterka pokazujące ruch z tyłu.
- [ ] `W/S` zmieniają prędkość płynnie; prędkość widoczna na HUD.
- [ ] `A/D` wykonują animowaną zmianę pasa; zmiana poza skrajny pas oznacza zjazd z drogi.
- [ ] `Q/E` przełączają kierunkowskaz z wizualizacją na HUD; kierunkowskaz gaśnie po manewrze.

### AI
- [ ] Pojazdy jadą z różnymi prędkościami, wyprzedzają wolniejsze i wracają na prawy pas.
- [ ] Pojazdy AI sygnalizują zmianę pasa.
- [ ] Pojazdy AI nie powodują kolizji same z siebie i nie pojawiają się w kolizji z graczem.
- [ ] Wyższy poziom trudności daje zauważalnie większą liczbę pojazdów.

### Ocenianie
- [ ] Przy 140 km/h i odstępie 50 m naliczana jest kara K1; przy 75 m kara nie jest naliczana.
- [ ] Kara K1 przy odstępie 20 m jest większa niż przy 50 m (przy tej samej prędkości).
- [ ] K1 nie jest naliczana w trakcie wyprzedzania.
- [ ] Pozostanie na lewym pasie przy wolnym prawym: podpowiedź w karencji, kara dopiero po jej upływie.
- [ ] Zmiana pasa bez kierunkowskazu daje karę K3; z kierunkowskazem ≥ 1 s i w uzasadnionej sytuacji daje nagrodę N1.
- [ ] Wielokrotne bezcelowe zmiany pasa nie zwiększają wyniku.
- [ ] Jazda prawym pasem z poprawnym odstępem stale zwiększa wynik.

### Tryby i sesja
- [ ] Sesja kończy się automatycznie po 90 s.
- [ ] Tryb nauki: podpowiedzi i komunikaty widoczne na bieżąco; po kolizji gracz wraca na drogę i jedzie dalej.
- [ ] Tryb egzaminu: brak podpowiedzi; kolizja lub zjazd z drogi kończy sesję z podaniem przyczyny.
- [ ] Oba tryby kończą się podsumowaniem z wynikiem, kategoriami i opisem słownym.

### Zapis
- [ ] Wynik sesji zapisuje się i jest widoczny w historii po odświeżeniu strony.
- [ ] Rekord dla kombinacji tryb × profil × poziom jest aktualizowany.

### Platforma
- [ ] Eksport web uruchamia się na statycznym hostingu bez dodatkowych nagłówków.
- [ ] Gra osiąga ≥ 30 FPS na laptopie ze zintegrowaną grafiką na poziomie trudności 4.

---

## 17. Proponowana kolejność implementacji (dla Claude Code)

1. **Szkielet projektu**: Godot 4.x, renderer Compatibility, Input Map, struktura katalogów, eksport web z testowym „hello world” na hostingu (weryfikacja pipeline'u na samym początku).
2. **`core/sim`** + testy: stan pojazdów, ruch po pasach, zmiana pasa, `LaneQuery` (8.4).
3. **Droga 3D**: segmenty, recykling, floating origin, profile drogi.
4. **Gracz**: sterowanie, kamera z kabiny, HUD (prędkość, limit, kierunkowskaz, czas).
5. **AI ruchu**: car-following, wyprzedzanie, powrót na prawy pas, spawn i pooling, poziomy gęstości.
6. **Lusterka**.
7. **Ocenianie** + dziennik zdarzeń + testy jednostkowe reguł K1–K4, N1–N3.
8. **Tryby, sesja 90 s, kolizje i zjazd z drogi**.
9. **Informacja zwrotna**: komunikaty bieżące + generator podsumowania.
10. **Zapis wyników i historia**.
11. **Samouczek, menu, ustawienia jakości**.
12. **Strojenie parametrów i testy z użytkownikami.**

---

## 18. Słowniczek

| Termin | Znaczenie |
|---|---|
| Odstęp minimalny | `prędkość [km/h] / 2` w metrach (art. 19 PoRD) |
| Pas wolny | Pas bez pojazdów w strefie `look_behind`–`look_ahead` wokół pojazdu |
| Karencja | Czas, przez który pozostanie na lewym pasie nie jest jeszcze karane |
| Sesja | Pojedynczy przejazd trwający 90 s |
| Dziennik zdarzeń | Lista ocenianych zdarzeń sesji, źródło informacji zwrotnej |
| Floating origin | Technika utrzymywania gracza blisko punktu (0,0,0) świata, by uniknąć błędów precyzji |
