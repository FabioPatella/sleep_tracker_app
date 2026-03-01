# Visualizzazione Dati Sonno

Il sistema mostra le statistiche sul sonno all'interno del componente aggregato `SleepStatistics.vue`. Esistono **due tipologie di visualizzazione principale**, a seconda del periodo selezionato: la **Vista per Periodo** (Range di date) e la **Vista Singola Giornata**.

## 1. Vista per Periodo (Range)
L'utente può selezionare l'analisi dei dati per archi temporali predefiniti (1 Settimana, 1 Mese, 3 Mesi) o specificare un Range Personalizzato. Questa vista mostra dati aggregati e storici:

### Indicatori di Sintesi (Card Averages)
In alto vengono mostrate tre card con il valore medio del periodo di riferimento:
- **Average Sleep (Sonno Medio):** Media matematica delle ore dormite mensili/settimanali misurate in ore (es. `7.5h`). Calcolato sul `totalHoursSlept` fornito dal backend.
- **Average Intensity (Intensità Media):** La qualità media del riposo, valutata in decimi (es. `8.0/10`). Calcolata sul `weightedAverageIntensity`.
- **Average Awakenings (Risvegli Medi):** Numero medio di volte in cui l'utente si è risvegliato nel periodo misurato. Derivato dal `numberOfRisvegli`.

### Grafico Interattivo (Chart.js)
Il andamento dei dati sul sonno vien plottato usando un grafico lineare (`vue-chartjs` / Line element) che mostra parallelamente tre tracciati:
- **Hours Slept (Linea Verde):** Totale delle ore dormite nei rispettivi giorni.
- **Intensity (Linea Arancione):** Valore della qualità (1-10).
- **Awakenings (Linea Blu):** Numero di risvegli avuti per notte.

> **Funzionalità Interattiva:** Cliccare su uno dei punti del grafico permette di entrare nel dettaglio di quello specifico giorno transizionando automaticamente alla "Vista Singola Giornata".

---

## 2. Vista Singola Giornata (Single Day)
Questa vista si attiva quando si seleziona "Single Day" tramite l'apposito picker o cliccando su un punto dal grafico. Mostra il dettaglio nudo e crudo di come è trascorsa la notte selezionata.

### Sezione: Note (Notes)
- Un riquadro che mostra eventuali appunti testuali inseriti dall'utente per quella notte (es. sintomi, sensazioni e annotazioni libere).

### Sezione: Dettaglio Intervalli (Sleep Intervals)
L'aspetto più granulare della visualizzazione, che esplode la notte in blocchi. Per ogni blocco/intervallo inserito viene mostrato:
- **Orario di addormentamento e sveglia:** Es. `23:30 - 05:00`
- **Durata effettiva dell'intervallo:** Trasformato in ore/minuti, es. `Duration: 5h 30m`
- **Intensità Specifica:** Valore/Voto della qualità registrata dall'utente unicamente per quel blocco (Es. `7/10`).

### Card di Recap del Giorno
Similmente alla vista di periodo, un recap tirato sui numeri della singola notte calcolati front-end lato Vue:
- **Total Sleep (Sonno Totale):** Somma della durata di tutti i singoli intervalli.
- **Average Intensity (Intensità Media):** L'intensità media generata unicamente dagli intervalli di quel giorno.
- **Awakenings (Risvegli):** Il totale numero di risvegli avvenuti quel giorno, calcolati visivamente sottraendo `1` al numero massimo di intervalli creati la sera d'appartenenza (`intervals.length - 1`).
