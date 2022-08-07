# CBReader - The Comic Book Reader

The CBReader is a comic book reader and editor. It also stores your reading history so you can resume reading right where you stopped.
As an editor, you can reorder pages, join double pages, and edit its data.

## About the Comic Book Archive Format Used

A comic book archive is, as the name implies, an archive, and it holds the pages of a certain comic book.
It can be a ZIP, RAR, TAR, etc..., as described in the [Wikipedia page](https://en.wikipedia.org/wiki/Comic_book_archive)

The CBReader will attempt to read any archive (of the supported formats) with images, however, in some cases the pages can be read out of order
(due to its filename in the archive), in such cases you can edit the order and update the archive.

The archives created/updated by this program will have the following structure:

```
# Single chapter

- 01.png
- 02.png
- ...
- [thumbnail.png]
- [metadata.json]

===================

# Multiple chapters

- 1 (chapter number)
  | - 01.png
  | - 02.png
  | - ...
  | - [thumbnail.png] (chapter thumbnail)
- 2
  | - ...
- [thumbnail.png] (volume thumbnail)
- [metadata.json]

===================

# Multiple volumes

- 1 (volume number)
  | - 1 (chapter number)
  |   | - 01.png
  |   | - 02.png
  |   | - ...
  |   | - [thumbnail.png] (chapter thumbnail)
  | - 2
  |   | - ...
  | - [thumbnail.png] (volume thumbnail)
- 2
  | - ...
- [thumbnail.png] (comic book thumbnail)
- [metadata.json]
```

### Page number

Each chapter will number its pages starting from 1 and will pad the value with zeroes*. This way the pages can be easily sorted alphabetically.

*\* the number will be padded so as all the pages have the same number of characters. Ex: 1.jpg - 8.jpg, 01.jpg - 25.jpg, 0001.jpg - 1234.jpg*

### Chapter number

The chapter number can be any posive number, including zero and decimals, and will follow the same padding policy of the pages.

### Volume number

Identical to [Chapter number](#chapter-number), 0.0+ numbers padded with zeroes.

### Thumbnail

Each archive/volume/chapter can have its own thumbnail, but it is not mandatory

### Metadata

Each archive can have its own metadata, but it is not mandatory

## Metadata File Format

The 