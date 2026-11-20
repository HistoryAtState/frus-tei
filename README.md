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

## Package

The repository builds an eXist-db package, `frus-tei`, installed at `/db/apps/frus-tei` with the same layout as the repository (`data/`, `resources/`, `catalog.xml`). `collection.xconf` and `index.xql` hold its index configuration; `pre-install.xql` stores both in `/db/system/config`. The configuration declares a vector field, so the package needs an eXist-db with the vector extension.

```shell
ant            # build/frus-tei.xar: the curated volume subset (see build.xml)
ant xar-full   # build/frus-tei.xar: the entire corpus
```

Since releases are automated, a local build can be given its own version, e.g. `ant -Dapp.version=X.X.X`. During a release, `-Drelease=true` regenerates `expath-pkg.xml` and `repo.xml` from their `.tmpl` files.

## Last-modified dates

`.last-modified/` holds one entry per file under `data/`, with the date of the last commit that changed it:

```xml
<last-modified xml:id="data0x2Ffrus1861.xml" seconds_since_epoch="1793156488">2026-10-28T03:01:28Z</last-modified>
```

CI ([`HistoryAtState/ci-actions` `last-mod.yml`](https://github.com/HistoryAtState/ci-actions)) updates the entries of the files a branch changes and commits them to that branch. `tools/seed-last-modified.sh` rewrites all of them from the git history.

## Release

Releases are automated: every push to `main` runs semantic-release, which publishes `frus-tei.xar` as a GitHub release.

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), which determine the release type; commitlint checks them in CI.

| Commit message | Release type |
|---|---|
| `fix(frus1981-88v05): correct the date of document 12` | Patch release |
| `feat: add frus1981-88v42` | Feature release |
| `feat!: rename the volume collections`<br/><br/>`BREAKING CHANGE: volumes moved to data/volumes/.` | Breaking release |
