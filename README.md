# BN Shortener GitHub Action

Shorten links and Launch Check them in a workflow. A `check` fails the job when a link is not ready (destination
down, broken redirects, missing UTM tags, previews...), so a campaign link never goes out broken.

```yaml
- uses: broadnet/shortener-action@v1
  id: link
  with:
    api-key: ${{ secrets.BN_API_KEY }}
    command: shorten
    urls: https://example.com/releases/${{ github.ref_name }}
    tags: release
- run: echo "Short link: ${{ steps.link.outputs.short-url }}"

- uses: broadnet/shortener-action@v1
  with:
    api-key: ${{ secrets.BN_API_KEY }}
    command: check
    links: |
      b1.lc/Spring
      b1.lc/Promo
    strict: true          # warnings fail too
```

`command: run` passes `args` to the [bn command](https://b1.lc/docs/tools/cli/), e.g. `args: stats Spring --json`.

Outputs: `short-url`, `short-urls`, `verdict`, `json`. Results also go to the job summary. The action runs the
one-file `bn` command it ships (nothing is downloaded at run time); it needs `python3` (preinstalled on GitHub's
Ubuntu and macOS runners).

Create the API key in the dashboard (API Portal → API keys) and save it as a repository secret.

## License

MIT
