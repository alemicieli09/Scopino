# Associazione dei residui

Scansione manuale e rilevamento delle rimozioni usano ResidualScanEngine e ApplicationInventory.
L’inventario legge ricorsivamente le cartelle Applicazioni dell’utente e del sistema, CoreServices,
/Users/Shared e Application Support dell’utente. Non entra nei bundle .app e ignora i file nascosti.
NSWorkspace verifica inoltre gli identificativi candidati fuori da queste cartelle; un’app nel Cestino non è considerata attiva.
Una scansione non garantisce l’assenza di copie su altri volumi o cartelle non indicizzate.

Le associazioni usano identificativi integri, suffissi riconosciuti o il nome esatto dell’app.
Il database KnownResiduals.json fornisce percorsi espliciti, anche annidati. I percorsi hanno tre livelli:
associazione confermata (identificativo dell’app rimossa o database), da verificare (deduzione dal nome),
dati condivisi (group container o namespace dello stesso produttore di un’app presente).
Questi livelli descrivono l’associazione, non garantiscono che dati locali o documenti siano sacrificabili.
Ogni riga mostra il criterio utilizzato. Nessun risultato è preselezionato.
I percorsi riconosciuti come appartenenti a un’app presente sono esclusi, senza bloccare interi produttori.

Le scansioni includono HTTPStorages, WebKit, Cookies e PrivilegedHelperTools.
I file piccoli o vuoti restano visibili. I link simbolici non sono candidati alla pulizia.
Gli errori dell’inventario, della lettura delle directory e della misura ricorsiva vengono riportati;
la schermata vuota non dichiara mai che l’intero Mac è pulito.

L’helper v2 riceve il nuovo comando trashItems: non chiama removeItem.
Ricava l’utente dalla connessione XPC autenticata, controlla proprietà e permessi del suo Cestino
ed esegue lo spostamento con una destinazione univoca e una directory aperta senza seguire symlink.
Non ripiega sulla cancellazione definitiva quando lo spostamento fallisce.
I file privilegiati conservano la proprietà originale e sono recuperabili dal Cestino, eventualmente con autorizzazione amministrativa.
Con un vecchio helper la pulizia viene rifiutata con un messaggio di aggiornamento.
La migrazione dell’helper va verificata sulla build firmata e installata; i test non modificano i servizi del Mac.

I test usano directory temporanee e coprono Notion/Android, Calendar/rekordbox, identificativi con punti,
app annidate, separazione dei prodotti Microsoft, percorsi noti, piccoli residui e letture fallite.
