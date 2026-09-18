# Zenodo DOI — click path (author)

This session opens the **GitHub** private repository and tag
`v1.0.0-ieee-access-rev`. Zenodo cannot be authenticated from the agent.

## After the GitHub Release exists

1. Open https://zenodo.org and sign in with GitHub.
2. Account → GitHub → flip this private repository on (Zenodo can archive private GitHub repos you own).
3. GitHub → Releases → if missing, publish release `v1.0.0-ieee-access-rev` from the tag.
4. Wait for the Zenodo draft, open it, **Publish**.
5. Copy `https://doi.org/10.5281/zenodo.XXXXXXXX`.
6. Replace the placeholder `10.5281/zenodo.XXXXXXX` in:
   - `04_artigo/ieee_access/artigo_ems_mpc_datacenter_access.tex` (Data Availability)
   - `04_artigo/ieee_access/response_to_reviewers.tex` (R2.17)

Do not mint a DOI by uploading a zip by hand if the GitHub Release is already
linked — the GitHub webhook is the intended provenance.
