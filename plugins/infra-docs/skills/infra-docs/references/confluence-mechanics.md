# Confluence mechanics

`ewscripps.atlassian.net`, space key `Infra`, cloud id
`f1b0109f-4589-41f1-be54-d5789b627577`.

Two ways in, and you need both:

- **Atlassian MCP** — pages, search, comments. Convenient, but **has no attachment
  scope**, so it cannot upload a diagram.
- **REST v1** with a token — everything else, attachments especially.

## Credentials

`ATLASSIAN_EMAIL` and `ATLASSIAN_API_TOKEN` must be in the environment. On macOS they
live in `~/.config/zsh/secrets.zsh` and are **not exported into non-interactive shells**,
so a script that works in your terminal fails under an agent unless you source them:

```bash
source ~/.zshenv
```

Windows and other shells: see [platforms.md](platforms.md).

Never hardcode the token, and never echo it into a log or a page body.

## Bodies are HTML, not storage XML

The MCP page tools take **HTML**, which the server converts to ADF/storage.

```html
<h2>Heading</h2>
<p>Text with <code>a value</code> and <strong>emphasis</strong>.</p>
<table><thead><tr><th>A</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>
<pre><code class="language-bash">tofu plan</code></pre>
```

Two failures to avoid:

1. **Do not write storage XML.** `<ac:structured-macro>`, `<ac:rich-text-body>`,
   `<ac:plain-text-body>` and CDATA render as literal text on the page.
2. **Do not pre-escape entities.** Passing `&lt;p&gt;Hello&lt;/p&gt;` publishes the
   escape sequences visibly. Pass real `<p>Hello</p>`. This one is easy to do by
   reflex and the result looks obviously broken, so check the first page you publish.

Raw REST takes **storage** format instead, so the two paths are not interchangeable —
read the body back before editing it and keep whatever representation it returns.

## Macros and links

Written as HTML extensions, not `<ac:...>`:

```html
<!-- children macro, for index pages -->
<div data-type="extension" data-extension-key="children"
     data-extension-type="com.atlassian.confluence.macro.core"
     data-parameters='{"macroParams":{"all":{"value":"true"}},
       "macroMetadata":{"schemaVersion":{"value":"1"},"title":"Children Display"}}'></div>
```

Cross-page links, in **storage** format when editing a fetched body:

```xml
<ac:link><ri:page ri:content-title="Troubleshooting — Hub Networking" />
  <ac:plain-text-link-body><![CDATA[Troubleshooting — Hub Networking]]></ac:plain-text-link-body>
</ac:link>
```

The `ri:content-title` must match the target title exactly, em-dashes included.

Dates render as a lozenge via `<time datetime="2026-09-19">…</time>`. Note it comes back
**empty** in the markdown export view — that is a rendering artifact of the export, not
a broken page.

## Creating pages

Parent-first, so children have a parent id to attach to. After every create, **check the
returned `title` matches what you asked for** — see the uniqueness rule in
[hierarchy-and-placement.md](hierarchy-and-placement.md).

Renaming without touching the body (v1 API allows a partial update):

```bash
curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" -X PUT \
  -H "Content-Type: application/json" \
  -d '{"version":{"number":2},"title":"New Title","type":"page"}' \
  "https://ewscripps.atlassian.net/wiki/rest/api/content/<PAGE_ID>"
```

Every update needs the next `version.number`; fetch the current one first.

## Attachments

The MCP cannot do this. Use REST:

```bash
curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
  -X POST "https://ewscripps.atlassian.net/wiki/rest/api/content/<PAGE_ID>/child/attachment" \
  -H "X-Atlassian-Token: nocheck" \
  -F "file=@diagram.svg"
```

`X-Atlassian-Token: nocheck` is required; without it the request is rejected as XSRF.

**Posting a filename that already exists returns HTTP 400** — it does not version:

```
Cannot add a new attachment with same file name as an existing attachment
```

To replace one, post to that attachment's `/data` endpoint instead:

```bash
curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
  -X POST ".../content/<PAGE_ID>/child/attachment/<ATTACHMENT_ID>/data" \
  -H "X-Atlassian-Token: nocheck" -F "file=@diagram.svg"
```

That does create a new version. The body references attachments by filename, so once
the name is stable a re-render needs no body edit — `confluence.py attach` picks the
right endpoint automatically.

Reference it from the body (storage format):

```xml
<ac:image ac:align="center" ac:width="820" ac:alt="…">
  <ri:attachment ri:filename="multi-region-topology.svg" />
</ac:image>
```

SVG uploads must carry `Content-Type: image/svg+xml`; `mimetypes.guess_type` gets this
right, a hardcoded `application/octet-stream` does not and the image will not render.

## `confluence.py`

`assets/confluence.py` wraps the above. Everything it does is reproducible with the
`curl` calls on this page.

```bash
source ~/.zshenv          # Windows: see platforms.md
python3 assets/confluence.py tree       --space Infra [--page <id>]
python3 assets/confluence.py publish    --parent <id> --title "…" --file page.html
python3 assets/confluence.py attach     --page <id> --file d.svg [--place-before '<h2>X']
python3 assets/confluence.py verify     --page <id>
python3 assets/confluence.py provenance --page <id> [--stamp <sha>]
```

## Gotchas

- Descendants paginate at 250 with a cursor in `_links.next`.
- Search result `summary` fields are cached and can lag the real body — read
  `body.storage` to check what actually published.
- Page titles are unique per space; collisions silently become " (2)".
- When comparing attachment filenames against body references, **decode HTML entities
  first**. An em-dash stored as `&mdash;` will not string-match the attachment's `—` and
  produces a false "broken image" report.
- Deleting a page is permanent. Confirm with the user first, every time.
