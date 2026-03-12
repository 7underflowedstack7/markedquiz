# Download Feature: From PostgreSQL to the User's Hands

**Category:** Swift/SwiftUI -- iOS Networking & File Management
**Subcategory:** URLSession, FileManager, UIActivityViewController, ShareLink
**Prerequisites:** Swift async/await basics, SwiftUI state management, MarkedQuiz codebase familiarity

---

## The Big Picture

You want to let a user tap "Download" in your MarkedQuiz app and save a markdown document from your Render-hosted PostgreSQL database to their device. This sounds simple, but it crosses **four distinct boundaries**:

```
+=====================================================================+
|                        YOUR DOWNLOAD PIPELINE                        |
+=====================================================================+
|                                                                     |
|  [PostgreSQL on Render]                                             |
|        |                                                            |
|        | 1. SQL query retrieves document content (Text column)      |
|        v                                                            |
|  [FastAPI Backend]                                                  |
|        |                                                            |
|        | 2. Serializes to HTTP response with Content-Disposition    |
|        v                                                            |
|  ~~~ INTERNET (HTTPS) ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   |
|        |                                                            |
|        | 3. URLSession receives bytes on the iOS device             |
|        v                                                            |
|  [iOS App Sandbox]                                                  |
|        |                                                            |
|        | 4. FileManager writes to temp directory                    |
|        v                                                            |
|  [Share Sheet / Files App]                                          |
|        |                                                            |
|        | 5. User chooses where to save or share                     |
|        v                                                            |
|  [User's chosen destination]                                        |
|                                                                     |
+=====================================================================+
```

Each boundary has its own rules, its own failure modes, and its own security implications. This lesson covers all of them.

---

## Chapter 1: The Backend -- What's Already Built

Before writing any Swift, you need to understand what your server provides. Look at your `documents.py` router. You already have a download endpoint:

```
GET /api/documents/{document_id}/download
```

**Question to think about:** Your backend has *two* ways to get document content -- `GET /api/documents/{id}` returns JSON with `title`, `content`, and `created_at`. The download endpoint at `GET /api/documents/{id}/download` returns raw markdown with a `Content-Disposition` header. *Why would you want both? When would you use one vs. the other?*

Take a moment to consider this before reading on.

---

The key difference is **intent**:

- The JSON endpoint is for your *app to consume* -- it parses the response, displays it in SwiftUI views, uses the structured data.
- The download endpoint is for *saving as a file* -- it sends raw bytes with a filename hint in the header. The browser (or your app) treats it as "here's a file to save."

The `Content-Disposition: attachment; filename="..."` header is the server's way of saying: "This isn't a page to display. This is a file to download. Here's what to call it."

```
+---------------------------------------------------------------+
|                   HTTP RESPONSE COMPARISON                     |
+---------------------------------------------------------------+
|                                                                |
|  JSON endpoint (/api/documents/5):                             |
|  +---------------------------------------------------------+  |
|  | Status: 200 OK                                          |  |
|  | Content-Type: application/json                          |  |
|  | Body: {"id": 5, "title": "My Doc", "content": "# ..."}|  |
|  +---------------------------------------------------------+  |
|  --> App parses JSON, uses structured fields                   |
|                                                                |
|  Download endpoint (/api/documents/5/download):                |
|  +---------------------------------------------------------+  |
|  | Status: 200 OK                                          |  |
|  | Content-Type: text/markdown                             |  |
|  | Content-Disposition: attachment; filename="my-doc.md"   |  |
|  | Body: # My Doc\n\nThe raw markdown content...           |  |
|  +---------------------------------------------------------+  |
|  --> App saves bytes directly to a file                        |
|                                                                |
+---------------------------------------------------------------+
```

**Your current code takes a shortcut.** Look at `downloadDocument()` in your `LibraryView.swift` -- it fetches the *JSON* endpoint via `fetchDocument(id:)`, then extracts the content string and writes it to a file manually. This works, but it means you're not using the purpose-built download endpoint at all.

**Question:** What are the trade-offs of the current approach (fetch JSON, extract content) vs. using the dedicated download endpoint? Think about: payload size, the filename, and what happens if the backend ever adds file format conversion.

---

## Chapter 2: URLSession -- Your Network Swiss Army Knife

### The Analogy: URLSession as a Mail Room

Think of `URLSession` as your app's mail room. It has different services depending on what kind of package you're sending or receiving:

```
+=========================================================+
|                   URLSession MAIL ROOM                    |
+=========================================================+
|                                                          |
|  WINDOW 1: data(from:)                                   |
|  "Small packages" -- JSON, short text responses          |
|  --> Loads everything into memory at once                 |
|  --> What your APIClient uses now                        |
|                                                          |
|  WINDOW 2: download(from:)                               |
|  "Large packages" -- files, images, PDFs                 |
|  --> Streams to a temporary file on disk                 |
|  --> Gives you a file URL, not raw Data                  |
|  --> Can report progress as bytes arrive                 |
|                                                          |
|  WINDOW 3: upload(for:from:)                             |
|  "Outgoing packages" -- sending files to a server        |
|  --> Streams from disk, doesn't load into memory         |
|                                                          |
|  WINDOW 4: bytes(from:)                                  |
|  "Conveyor belt" -- AsyncSequence of bytes               |
|  --> Process data as it arrives, chunk by chunk          |
|  --> Good for streaming or real-time feeds               |
|                                                          |
+=========================================================+
```

Your `APIClient` exclusively uses Window 1 (`data(from:)` and `data(for:)`). For downloading markdown files -- which are small text files -- this works fine. But understanding the difference matters because:

1. **`data(from:)` loads the entire response into a `Data` object in memory.** For a 5KB markdown file, no problem. For a 500MB PDF? Your app gets killed by the OS.

2. **`download(from:)` streams to a temporary file on disk.** Memory stays low. You get a `URL` pointing to the downloaded file instead of a `Data` blob.

### The async/await Pattern

Your `APIClient` already uses Swift's async/await with URLSession. Here's the pattern you know:

```swift
let (data, response) = try await URLSession.shared.data(from: url)
```

The download equivalent follows the exact same shape:

```swift
let (tempFileURL, response) = try await URLSession.shared.download(from: url)
```

**Key difference:** `data(from:)` returns `(Data, URLResponse)`. `download(from:)` returns `(URL, URLResponse)`. That URL points to a temporary file the system will delete -- you must move it somewhere persistent before the system cleans it up.

**Question:** Your `APIClient` has a generic `get<T: Decodable>` helper that decodes JSON. Could you use this same pattern for a download? Why or why not?

### Progress Tracking

Here's where downloads diverge from simple data fetches. When downloading, users expect feedback -- a progress bar, a spinner with percentage, *something*. URLSession provides this through `URLSessionDownloadDelegate` in the callback world, but with async/await you have two options:

**Option A: The `bytes(from:)` approach** -- Read the response as an `AsyncSequence` of bytes, counting as you go. You need the `Content-Length` header from the response to calculate percentage.

**Option B: Observation with `Progress`** -- Use `URLSession`'s built-in `Progress` tracking via a download task's `progress` property.

**For your markdown files**, which are small and download in under a second, an indeterminate `ProgressView()` (the spinning kind) is probably sufficient. But knowing *how* to show real progress is essential for when you eventually download larger content.

```
+-----------------------------------------------------------+
|              PROGRESS TRACKING DECISION TREE               |
+-----------------------------------------------------------+
|                                                            |
|  Is the file typically < 1MB?                              |
|       |                                                    |
|       +-- YES --> Use indeterminate ProgressView()         |
|       |           (spinner, no percentage)                 |
|       |                                                    |
|       +-- NO ---> Does the server send Content-Length?     |
|                       |                                    |
|                       +-- YES --> Show determinate bar     |
|                       |           ProgressView(value:)     |
|                       |                                    |
|                       +-- NO ---> Use indeterminate +      |
|                                   "Downloaded X MB" text   |
|                                                            |
+-----------------------------------------------------------+
```

### Connecting to Your Existing APIClient

Look at your `APIClient` structure. It has `get`, `post`, and `delete` private helpers. To add download capability, you'd follow the same pattern -- but the return type isn't `Decodable` JSON. It's a file URL.

**Think about this:** Should the download method go in your `APIClient`, or should it live somewhere else? Consider what `APIClient` currently does (network requests that return decoded Swift types) vs. what a download does (network request that returns a file). There's no wrong answer, but the reasoning matters.

---

## Chapter 3: FileManager -- The iOS File System

### The Analogy: The Sandbox as an Apartment Building

iOS apps live in a **sandbox** -- think of it like an apartment building where each app gets its own apartment. You can rearrange furniture inside your apartment all you want, but you can't walk into another tenant's unit.

```
+=============================================================+
|                iOS SANDBOX "APARTMENT BUILDING"              |
+=============================================================+
|                                                              |
|  YOUR APP'S APARTMENT                                        |
|  +-------------------------------------------------------+  |
|  |                                                       |  |
|  |  [Documents/]       <-- User-visible in Files app     |  |
|  |  Your personal      Backed up to iCloud               |  |
|  |  filing cabinet      Persists across updates           |  |
|  |                                                       |  |
|  |  [Library/Caches/]  <-- System can purge when low     |  |
|  |  The junk drawer     on disk space                     |  |
|  |                      NOT backed up                     |  |
|  |                                                       |  |
|  |  [tmp/]             <-- System cleans periodically     |  |
|  |  The doormat         Truly temporary                   |  |
|  |                      NOT backed up                     |  |
|  |                                                       |  |
|  +-------------------------------------------------------+  |
|                                                              |
|  SHARED SPACES (Requires Permission)                         |
|  +-------------------------------------------------------+  |
|  |  Photos Library     <-- PHPhotoLibrary permission      |  |
|  |  iCloud Drive       <-- Entitlement + UIDocument       |  |
|  |  Shared Containers  <-- App Groups entitlement         |  |
|  +-------------------------------------------------------+  |
|                                                              |
+=============================================================+
```

### Which Directory Do You Use?

This decision matters more than most developers realize:

| Directory | Use When | Lifespan | Backed Up |
|-----------|----------|----------|-----------|
| `tmp/` | Staging area before sharing | Minutes to hours | No |
| `Documents/` | User's files they expect to keep | Until user deletes | Yes |
| `Library/Caches/` | Re-downloadable data | Until system purges | No |

**For your download feature:** The user is downloading to *share or export* -- they'll pick the final destination via the share sheet. So you write to `tmp/` as a staging area. This is exactly what your current code does with `FileManager.default.temporaryDirectory`.

### FileManager Essentials

`FileManager.default` is your interface to the file system. The key operations you need:

```
+--------------------------------------------------+
|          FileManager Operations You Need          |
+--------------------------------------------------+
|                                                   |
|  .temporaryDirectory                              |
|     --> URL to your app's tmp/ folder             |
|                                                   |
|  .urls(for:in:)                                   |
|     --> Find Documents/, Caches/, etc.            |
|                                                   |
|  .fileExists(atPath:)                             |
|     --> Check before overwriting                  |
|                                                   |
|  .moveItem(at:to:)                                |
|     --> Move downloaded temp file to final spot   |
|                                                   |
|  .removeItem(at:)                                 |
|     --> Clean up temp files after sharing          |
|                                                   |
|  .createDirectory(at:withIntermediateDirectories:) |
|     --> Ensure parent directories exist           |
|                                                   |
+--------------------------------------------------+
```

**Security note:** When working with filenames that come from the server (or user input), always sanitize them. Your backend generates filenames from the document title:

```python
filename = doc.title.replace(" ", "-").lower() + ".md"
```

**Question:** What happens if someone creates a document titled `"../../etc/passwd"`? Walk through what the backend would produce as a filename. Then think about what happens on the iOS side when you use that filename with `temporaryDirectory.appendingPathComponent(filename)`. Path traversal attacks are a real category of vulnerability -- even if `appendingPathComponent` handles it safely, you should understand *why* it's safe (or not).

### Writing Data to Disk

Your current code writes the content string directly:

```swift
try detail.content.write(to: tempURL, atomically: true, encoding: .utf8)
```

The `atomically: true` parameter is worth understanding. It means:

1. Swift writes to a *temporary* hidden file first
2. Only after the write completes successfully does it rename (move) the temp file to the target path
3. If the write fails partway through, the original file (if any) remains untouched

This is a **transaction** -- the same concept as in your PostgreSQL database. Either the entire write succeeds, or nothing changes. Without `atomically: true`, a crash mid-write could leave a corrupted half-written file.

---

## Chapter 4: Presenting the Download -- UI Patterns

### Three Ways to Let Users Save Files

SwiftUI gives you several approaches to let users save or share downloaded files:

```
+=============================================================+
|              FILE SHARING UI OPTIONS                         |
+=============================================================+
|                                                              |
|  1. ShareLink (SwiftUI native, iOS 16+)                      |
|     +---------------------------------------------------+   |
|     | Built-in SwiftUI view                              |   |
|     | Wraps UIActivityViewController                     |   |
|     | Declarative -- just provide the data               |   |
|     | Best for: simple sharing of known data             |   |
|     +---------------------------------------------------+   |
|                                                              |
|  2. UIActivityViewController (UIKit bridge)                  |
|     +---------------------------------------------------+   |
|     | The classic share sheet                            |   |
|     | Requires UIViewControllerRepresentable wrapper      |   |
|     | More control over presentation                     |   |
|     | Best for: when you need dynamic items              |   |
|     +---------------------------------------------------+   |
|                                                              |
|  3. fileExporter (SwiftUI native, iOS 14+)                   |
|     +---------------------------------------------------+   |
|     | System file-save dialog                            |   |
|     | User picks exactly where to save                   |   |
|     | Requires Transferable conformance                   |   |
|     | Best for: "Save As" workflows                      |   |
|     +---------------------------------------------------+   |
|                                                              |
+=============================================================+
```

Your codebase already uses **two** of these:

- `DocumentDetailView` uses `ShareLink` -- the SwiftUI-native approach. It writes the file in the view body (during rendering!) and hands the URL to `ShareLink`.

- `LibraryView` uses a `ShareSheetView` wrapper around `UIActivityViewController`, triggered after an async download completes.

**Question:** Look at the `shareDownloadButton(document:)` method in your `DocumentDetailView`. It calls `try? document.content.write(to: tempURL, ...)` inside a computed view property. What's potentially wrong with performing file I/O during view rendering? Think about what happens when SwiftUI re-evaluates the body -- which it does frequently.

### ShareLink Deep Dive

`ShareLink` is the modern SwiftUI approach. It works declaratively:

```
+----------------------------------------------------------+
|                    ShareLink DATA FLOW                     |
+----------------------------------------------------------+
|                                                           |
|  ShareLink(item: someURL)                                 |
|       |                                                   |
|       | User taps the link                                |
|       v                                                   |
|  System presents UIActivityViewController                 |
|       |                                                   |
|       | Available actions depend on the item type:        |
|       |   URL to file  --> Save to Files, AirDrop,        |
|       |                    Mail, Messages, etc.           |
|       |   String       --> Copy, Mail, Messages           |
|       |   Image        --> Save to Photos, AirDrop        |
|       v                                                   |
|  User picks an action                                     |
|       |                                                   |
|       v                                                   |
|  System handles the transfer                              |
|                                                           |
+----------------------------------------------------------+
```

For file downloads, you provide a `URL` pointing to a local file. The share sheet then offers options like "Save to Files," AirDrop, email, etc.

### The fileExporter Alternative

If you want a more focused "Save As" experience (no social sharing options, just pick a location), `fileExporter` is the right tool. It requires your data to conform to `Transferable` -- a protocol that tells the system how to represent your data for transfer.

**Think about this:** For your MarkedQuiz app, which UI pattern makes the most sense? The share sheet gives flexibility (save, share, AirDrop). The file exporter is more focused (just save). Consider your user's intent when they tap "Download."

### Progress Indicators in SwiftUI

SwiftUI provides `ProgressView` in two flavors:

**Indeterminate** (spinning wheel -- "something is happening"):
```swift
ProgressView()  // No parameters
```

**Determinate** (progress bar -- "we're 60% done"):
```swift
ProgressView(value: 0.6)  // 0.0 to 1.0
```

For your download feature, you need to connect the download state to the UI. Your `LibraryView` already has `@State private var isDownloading = false` -- but this is a binary state. For a progress bar, you'd need a `Double` tracking the fraction complete.

```
+--------------------------------------------------+
|           STATE MACHINE FOR DOWNLOADS             |
+--------------------------------------------------+
|                                                   |
|  .idle                                            |
|     |                                             |
|     | User taps download                          |
|     v                                             |
|  .downloading(progress: Double)                   |
|     |                                             |
|     +-- Progress updates (0.0 ... 1.0)            |
|     |                                             |
|     +-- Network error --> .failed(Error)          |
|     |                                             |
|     | Download completes                          |
|     v                                             |
|  .completed(fileURL: URL)                         |
|     |                                             |
|     | User dismisses share sheet                  |
|     v                                             |
|  .idle  (clean up temp file)                      |
|                                                   |
+--------------------------------------------------+
```

**Question:** Your current code uses a simple `Bool` for download state. What would an `enum`-based state machine look like? How would it handle the error case that your current `Bool` can't represent? (Hint: think about how your `APIError` enum already models multiple error states.)

---

## Chapter 5: Security Considerations

Security is not an afterthought. Here are the threats specific to a download feature:

### 1. Transport Security

Your app communicates over HTTPS (`https://markedquiz.onrender.com`). This means:

- Data is encrypted in transit -- no one between the device and Render can read the content
- The server's identity is verified -- you know you're talking to the real server
- iOS enforces App Transport Security (ATS) by default, which *requires* HTTPS

**If you ever use HTTP (no 's')**, iOS will block the request unless you add an exception to your Info.plist. Don't add that exception. Fix the URL instead.

### 2. Input Validation -- The Filename Problem

```
+================================================================+
|                 FILENAME SANITIZATION                            |
+================================================================+
|                                                                 |
|  SERVER generates filename from document title:                 |
|                                                                 |
|    doc.title = "My Cool Document"                               |
|    filename  = "my-cool-document.md"      <-- SAFE              |
|                                                                 |
|    doc.title = "../../etc/passwd"                                |
|    filename  = "../../etc/passwd.md"      <-- DANGEROUS?        |
|                                                                 |
|  iOS DEFENSE LAYERS:                                            |
|                                                                 |
|  Layer 1: appendingPathComponent() normalizes the path          |
|           "../" sequences are resolved relative to the base     |
|           Result stays within the intended directory             |
|                                                                 |
|  Layer 2: App sandbox prevents writing outside your container   |
|           Even if path traversal succeeded, the OS blocks it    |
|                                                                 |
|  Layer 3: tmp/ directory is already isolated                    |
|           Nothing critical lives there to overwrite             |
|                                                                 |
|  BUT: Defense in depth means you should STILL sanitize.         |
|  Don't rely on the last layer of defense being perfect.         |
|                                                                 |
+================================================================+
```

**Best practice:** Strip path separators and other dangerous characters from filenames before using them. A simple sanitization function that keeps only alphanumerics, hyphens, and dots goes a long way.

### 3. Content Validation

Your backend only allows `.md` files (the upload endpoint checks `file.filename.endswith(".md")`). But the download side should also be cautious:

- **Check the response status code** before processing the body. Your `validateResponse` method already does this.
- **Check Content-Type** if you want to be thorough -- make sure the server sent `text/markdown` and not something unexpected.
- **Limit file size** -- even for text files, consider setting a maximum. A malicious or buggy server could send gigabytes of data. `URLSession` configuration has a `timeoutIntervalForResource` property that helps with this.

### 4. Temporary File Cleanup

Files in `tmp/` are cleaned up by the system *eventually*, but not immediately. If your app downloads many files in one session, you could accumulate significant temporary storage.

**Good practice:** Clean up your temp files after the share sheet is dismissed. Your current code doesn't do this -- the `downloadFileURL` stays around until the next download overwrites it.

**Question:** Where in the SwiftUI lifecycle would you clean up the temporary file? Think about the `onDismiss` parameter of `.sheet()` and when it fires.

### 5. Memory Considerations

Your current approach loads the entire document content into memory (as a `String` inside `DocumentDetail`), then writes it to disk. For markdown lesson files, this is fine -- they're typically kilobytes. But be aware of the ceiling:

```
+--------------------------------------------------+
|          MEMORY vs. STREAMING THRESHOLDS          |
+--------------------------------------------------+
|                                                   |
|  < 10 MB    : data(from:) is fine                 |
|  10-50 MB   : Consider download(from:)            |
|  > 50 MB    : MUST use download(from:) or         |
|               bytes(from:) with streaming         |
|  > 200 MB   : Background download session         |
|               (survives app suspension)            |
|                                                   |
+--------------------------------------------------+
```

---

## Chapter 6: Putting It Together -- Architecture

Here's how all the pieces connect in your MarkedQuiz app:

```
+=================================================================+
|              DOWNLOAD FEATURE ARCHITECTURE                       |
+=================================================================+
|                                                                  |
|  LibraryView / DocumentDetailView                                |
|       |                                                          |
|       | User triggers download (button tap / context menu)       |
|       v                                                          |
|  ViewModel or View method (async)                                |
|       |                                                          |
|       | 1. Update state to .downloading                          |
|       v                                                          |
|  APIClient                                                       |
|       |                                                          |
|       | 2. URLSession.shared.data(from: downloadURL)              |
|       |    OR                                                    |
|       |    URLSession.shared.download(from: downloadURL)          |
|       v                                                          |
|  Response handling                                                |
|       |                                                          |
|       | 3. Validate HTTP status                                   |
|       | 4. Sanitize filename                                      |
|       | 5. Write to temp directory (atomically)                   |
|       v                                                          |
|  State update                                                     |
|       |                                                          |
|       | 6. Update state to .completed(fileURL)                    |
|       v                                                          |
|  ShareLink / Share Sheet / fileExporter                           |
|       |                                                          |
|       | 7. User picks action (Save to Files, AirDrop, etc.)      |
|       v                                                          |
|  Cleanup                                                          |
|       |                                                          |
|       | 8. Remove temp file                                       |
|       | 9. Reset state to .idle                                   |
|       |                                                          |
+=================================================================+
```

### Where Does Download Logic Belong?

Look at your current architecture:

- `LibraryViewModel` handles document CRUD operations
- `LibraryView` has a `downloadDocument()` method *directly in the view*
- `DocumentDetailView` writes files *inside a computed view property*

**Question:** Following the same pattern as your `LibraryViewModel` (which keeps network calls out of the view), where should the download logic live? And should it be in the *existing* ViewModel, or a new one? Think about the Single Responsibility Principle.

---

## Chapter 7: Cross-Stack Connections

Since you work across Python and Swift, here are useful parallels:

```
+===========================================================+
|             PYTHON <--> SWIFT CONCEPT MAP                  |
+===========================================================+
|                                                            |
|  Python (FastAPI)          |  Swift (SwiftUI)              |
|  -------------------------+-----------------------------   |
|  httpx.get() / aiohttp    |  URLSession.data(from:)       |
|  async with aiofiles      |  URLSession.download(from:)   |
|  Pydantic BaseModel       |  Codable protocol             |
|  os.path / pathlib        |  FileManager + URL            |
|  tempfile.NamedTempFile   |  FileManager.temporaryDir     |
|  with open() as f:        |  Data.write(to:) / String.    |
|                            |    write(to:atomically:)      |
|  @app.get(response_class  |  Content-Type check on        |
|    =FileResponse)         |    URLResponse                |
|  os.path.join() (safe)    |  URL.appendingPathComponent   |
|                            |    (safe, normalizes paths)   |
|                                                            |
+===========================================================+
```

**The `Codable` / `Pydantic` parallel** is especially relevant here. Your `DocumentDetail` Swift struct uses `CodingKeys` to map `snake_case` JSON to `camelCase` Swift properties -- the same job Pydantic's `model_config = {"from_attributes": True}` does on the Python side. When your download endpoint returns raw bytes instead of JSON, you skip this entire encoding/decoding layer.

---

## Chapter 8: Exercises

Now that you understand the concepts, here's the implementation path. Don't read ahead -- try each step before moving to the next.

### Exercise 1: Add a Download Method to APIClient

Add a new method to `APIClient` that hits the `/api/documents/{id}/download` endpoint. This method should:

- Return a `URL` pointing to the downloaded file in the temp directory
- Validate the HTTP response
- Sanitize the filename from the `Content-Disposition` header (or fall back to a default)
- Write the data to a temp file atomically

**Hint:** You'll need to parse `Content-Disposition` to extract the filename. The format is: `attachment; filename="some-name.md"`. Swift's `String` methods or a simple regex can handle this.

### Exercise 2: Create a Download State Enum

Replace the `Bool` download state with a proper enum that models all possible states: idle, downloading, completed (with URL), and failed (with error message). Put this in a place where both `LibraryView` and `DocumentDetailView` can use it.

### Exercise 3: Move Download Logic Out of the View

Refactor `downloadDocument()` out of `LibraryView` and into the appropriate ViewModel. The view should only read state and call a single async method.

### Exercise 4: Clean Up Temp Files

Add cleanup logic that removes the temporary file after the share sheet is dismissed. Test this by downloading a file, sharing it, then checking whether the temp file still exists.

### Exercise 5: Fix the DocumentDetailView Side Effect

The `shareDownloadButton(document:)` method performs file I/O during view rendering. Refactor it so the file is written *before* the view needs it (in an async context), and `ShareLink` only receives a pre-existing URL.

---

## Quick Reference: Key APIs

| API | What It Does | Apple Docs Keyword |
|-----|-------------|-------------------|
| `URLSession.shared.data(from:)` | Fetch response into memory | "Fetching website data" |
| `URLSession.shared.download(from:)` | Download to temp file on disk | "Downloading files" |
| `FileManager.default.temporaryDirectory` | Your app's tmp/ folder URL | "FileManager" |
| `FileManager.default.moveItem(at:to:)` | Move/rename a file | "FileManager" |
| `Data.write(to:options:)` | Write bytes to a file | "Data" |
| `String.write(to:atomically:encoding:)` | Write text to a file | "String" |
| `ShareLink` | SwiftUI declarative share button | "ShareLink" |
| `UIActivityViewController` | UIKit share sheet | "UIActivityViewController" |
| `.fileExporter()` | SwiftUI save-to-location dialog | "fileExporter" |
| `ProgressView` | Spinner or progress bar | "ProgressView" |
| `URL.appendingPathComponent(_:)` | Safely build file paths | "URL" |

---

## Summary Checklist

Before you consider the feature complete, make sure you can answer YES to all of these:

- [ ] Downloads use HTTPS (never HTTP)
- [ ] Filenames are sanitized before writing to disk
- [ ] HTTP status codes are validated before processing
- [ ] File writes use `atomically: true`
- [ ] Temporary files are cleaned up after use
- [ ] Download state is modeled as an enum, not a Bool
- [ ] File I/O never happens during view rendering (SwiftUI body)
- [ ] The user sees feedback during download (at minimum, a spinner)
- [ ] Error states are surfaced to the user, not silently swallowed
- [ ] The download works when the app is on a slow connection (timeout handling)

---

*Next lesson: Uploading files from the iOS app to your FastAPI backend -- multipart form data, streaming uploads, and the `fileImporter` modifier you're already using.*
