# busyboxx-downloader

Script for downloading BusyBoxx content headlessly. The BusyBoxx websites
limit downloading to 5 items at a time while many of their libraries contain
50, 100 or more assets.

Relies on env variables `BUSYBOXX_EMAIL` and `BUSYBOXX_PASSWORD`.

### Command line options

**Required:**

```
   --source (STR) ('busy' or 'animation') - where to download from.
```

**Optional:**

```
   --library (INT) - target the `n`th of your owned libraries.
   --start (INT) - skip downloading the libraries listed prior.
   --speed (STR) - ('slow' or 'fast') time to wait between iterations.
```

**Example calls:**

- `./download.rb --source busy`
- `./download.rb --source busy --library 5`
- `./download.rb --source animation --library 1 --start 3`
- `./download.rb --source animation --library 1 --start 3  --speed fast`
