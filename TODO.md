# Application

- [ ] Make a working alpha version
- [ ] Create Settings

# History

- [ ] Update the history entry definition

    ```typescript
    interface HistoryEntry {
        /// The path to the archive
        path: string;
        /// The path of the last page read
        page: string;
        /// The thumbnail of the comic book (first page if no thumbnail in the archive)
        thumbnail: string;
        /// The title of the comic book
        title?: string;
        /// The author of the comic book
        author?: string;
    }
    ```

- [ ] Decide whether the history will be persisted in a file/database(sqlite)/neutralino's storage
- [ ] Update history to match user reading progress
- [ ] Make entries deletable
- [ ] Clear history by period
- [ ] Remove history older than *n* days

# Home

- [ ] Show history by newer
- [ ] Make history sortable
- [ ] Make history searchable
- [ ] Message for when no history available
- [ ] Button for picking an archive (until a native drag&drop is available)

# Reader

- [ ] Show the progress of opening a file
- [ ] Show errors adequately
- [ ] Show page loading indicator
- [ ] Change the pages bar so when an archive has too many pages it doesn't overflow
- [ ] Create context menu for commands (join with next, split, ...)
- [ ] Show something to the user when there are no more pages
- [ ] Style the page indicator according to the page state (pages bar item)
- [ ] Change the window title to match the comic book
- [ ] Add controls to the UI, so the user can actually navigate

# Settings

### General

- [ ] Theme
- [ ] Shortcuts

### History

- [ ] History limit
- [ ] Anonymous reading (do not keep history)
- [ ] Days to keep history up to

### Reader

- [ ] Pages to cache
- [ ] Read direction
- [ ] Read mode
- [ ] Image scaling
