# Xcode-Agent-Prompt — Chat-Crash beim Rendern fixen

> Kopiere den Text zwischen den Linien 1:1 in den Xcode Claude-Agent.

---------------------------------------------------------------------------

**Bestätigte Diagnose (aus dem Debugger):** Die App pausiert/crasht in **`ChatView.conversationList.getter`** (Thread 1, ca. Zeile 92), DIREKT nachdem die Gesprächsdaten geladen wurden. Das Netzwerk ist in Ordnung — alle `GET /api/client/...` liefern **200**, `clientId=77`. Es ist also ein **SwiftUI-Render-Crash, kein Lade-Problem**. Ignoriere die Konsolenzeilen `RenderBox … default.metallib Error:2` und `tcp_input … flags=[R]` — beide sind harmlos.

**Ursache:** `conversationList` rendert `ForEach(vm.conversations)`, und `ChatConversation.id` ist `trainerId`. Seit das Parsing defensiv ist, gelangen Gespräche mit **leerem oder doppeltem `trainerId`** in die Liste. Ein SwiftUI-`ForEach` über **nicht eindeutige Identifiable-IDs stürzt ab**. Dasselbe Risiko besteht bei `ForEach(section.messages)` (id = `ChatMessage.id`).

**Aufgabe — minimal und gezielt beheben:**

1. In **`SihlClient/ViewModels/ChatViewModel.swift`** direkt nach dem Laden deduplizieren und leere IDs verwerfen:
   - `fetchConversations`: nach `let raw = try await service.getConversations(...)` nur das jeweils erste Gespräch pro **nicht-leerem** `trainerId` behalten (mit einem `Set<String>` der gesehenen IDs), das Ergebnis `conversations` zuweisen.
   - `fetchMessages`: gleiches Muster, dedupliziert über **nicht-leere** `ChatMessage.id`.

   Beispielmuster:
   ```swift
   var seen = Set<String>()
   conversations = raw.filter { c in
       guard !c.trainerId.isEmpty, seen.insert(c.trainerId).inserted else { return false }
       return true
   }
   ```

2. Prüfe in **`SihlClient/Views/ChatView.swift`**, ob es weitere `ForEach` über Server-Daten gibt, die doppelte/leere Identifiable-IDs enthalten könnten (Gesprächsliste + Nachrichtenliste sind die beiden, die Server-Daten rendern). Falls ja, ebenso absichern.

3. Verifizieren: `SihlClient`-Scheme bauen, auf dem Gerät „iPhone von JPM" starten, Chat-Tab öffnen. Die Liste muss erscheinen und **stabil bleiben**. In den Xcode-Runtime-Warnungen darf die lila Meldung **„ID … occurs multiple times within the collection"** NICHT mehr auftauchen.

**Nur** den Dedup-/Eindeutigkeits-Fix umsetzen. Keine UI-, Layout- oder sonstigen Änderungen.

---------------------------------------------------------------------------
