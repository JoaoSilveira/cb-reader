# Application

- [ ] Make a working alpha version
- [ ] Create Settings
- [ ] Add some documentation

# Elm Ports

- [ ] Fix `notifyPageChangePort` payload
- [ ] Investigate why `requestPagesPort` is taking too long on big archives

# History

- [x] Update the history entry definition

    ```typescript
    interface HistoryEntry {
        /** The path to the archive */
        path: string;
        /** The path of the last page read */
        page: string;
        /** The datetime of the entry */
        date: number;
        /** The thumbnail of the comic book (first page if no thumbnail in the archive) */
        thumbnail: string;
        /** The title of the comic book */
        title?: string;
        /** The author of the comic book */
        author?: string;
    }
    ```

- [x] Decide whether the history will be persisted in a file/database(sqlite)/neutralino's storage
- [x] Update history to match user reading progress
- [x] Make entries deletable
- [ ] Clear history by period
- [ ] Remove history older than *n* days
- [x] Make history sortable
- [ ] Make history searchable
- [ ] Save the thumbnail data, not its path

# Home

- [ ] Display loading indicator
- [x] Show history by newer
- [ ] Make history sortable
- [ ] Make history searchable
- [x] Message for when no history available
- [x] Button for picking an archive (until a native drag&drop is available)
- [ ] Rework the UI

    - [ ] Open archive button
    - [ ] History list
    - [ ] Search controls
    - [ ] Order controls
    - [ ] Loading feedback
    - [ ] Error message

# Reader

- [ ] Show the progress of opening an archive
- [ ] Show errors adequately
- [ ] Show page loading indicator
- [ ] Change the pages bar so when an archive has too many pages it doesn't overflow
- [ ] Create context menu for commands (join with next, split, ...)
- [ ] Show something to the user when there are no more pages
- [ ] Style the page indicator according to the page state (pages bar item)
- [ ] Change the window title to match the comic book
- [ ] Add controls to the UI, so the user can actually navigate
- [ ] Find an algorithm to sort the pages
- [ ] Rework the UI

    - [ ] Center pages shorter than height

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
