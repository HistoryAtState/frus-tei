# frus-tei

The *Foreign Relations of the United States* (FRUS) series in TEI, with each volume split into one file per document or division.

> **Status: work in progress.** The contents of this repository, including its layout, file names and encoding, are subject to change without notice. Don't build on it yet without checking with the Office of the Historian.

## Layout

- `data/{volume-id}/`: one directory per volume (694 in all).
  - `{volume-id}.xml`: the volume's root `tei:TEI`. It holds the header and the structure (titles and `xi:include`s), not the full text.
  - `{volume-id}_includes.xml`: the header pieces the volume and its documents share (title, publication and series statements).
  - `front/`, `body/`, `back/`: the volume's divisions. Each leaf division (a document, or a section of front or back matter) is its own file with the full text.
  - `{volume-id}_catalog.xml`: an OASIS XML catalog that resolves the volume's canonical URIs to these files.
- `catalog.xml`: the top-level catalog. It maps the canonical frus-tei-guidelines URIs to `resources/` and chains the per-volume catalogs, so links resolve offline in oXygen, xmllint and other tools.
- `resources/`: `frus-encodingDesc.xml` (the shared encoding description), `frus-placeholders.xml`, and an oXygen project file.

## Related repositories

- [HistoryAtState/frus-pipeline](https://github.com/HistoryAtState/frus-pipeline): the tools, in `cli/`, that convert the legacy single-file FRUS TEI into this form.
- [HistoryAtState/frus-tei-guidelines](https://github.com/HistoryAtState/frus-tei-guidelines): the schema (`frus.odd`) and rendition vocabulary these files follow.
