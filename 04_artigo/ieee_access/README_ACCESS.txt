IEEE Access — manuscript package (English, canonical for publication)
=====================================================================

Main LaTeX file:
  artigo_ems_mpc_datacenter_access.tex

Final PDF (local):
  artigo_ems_mpc_datacenter_access_FINAL.pdf

Submission ZIP (ready to upload):
  ../ieee_access_submission.zip

Required assets in this folder / ZIP:
  ieeeaccess.cls
  images/Logo.png
  images/notaglineLogo.png
  images/bullet.png
  Logo.png, notaglineLogo.png, bullet.png   (copies at folder root; required by cls)
  figuras/*.png

How to compile (local, MiKTeX/TeX Live):
  pdflatex artigo_ems_mpc_datacenter_access.tex
  pdflatex artigo_ems_mpc_datacenter_access.tex

Overleaf:
  1) Upload ieee_access_submission.zip (or this folder).
  2) Set artigo_ems_mpc_datacenter_access.tex as the main document.
  3) Recompile twice.

IEEE Author Portal / submission checklist:
  - Upload the PDF generated from this package (or compile on Overleaf and download PDF).
  - Keep header placeholders as-is for first submission:
      Date of publication xxxx 00, 0000
      DOI 10.1109/ACCESS.2026.DOI
    IEEE fills real dates/DOI after acceptance (galley proof).
  - Prefer replacing ieeeaccess.cls + logos with the official package from:
      https://template-selector.ieee.org/
      (Transactions/Journals → IEEE Access → LaTeX)
    before camera-ready if the editor requests it.
  - Portuguese version (04_artigo/ieee_pt/) is a personal backup only — not for IEEE Access upload.
  - Supplemental MATLAB/CSV (if required by the journal): see 06_suplementar/.

Notes:
  - Custom Access fonts (Formata / Giovanni) may be missing locally; layout remains usable.
  - Overleaf’s official Access template usually includes the proprietary fonts.
