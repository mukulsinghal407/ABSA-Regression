# HANDOFF – Big Data Final Report (continue in local session)

## 1. Goal
Write the final project report in **local Microsoft Word (.docx)** following
`Big_Data_Project_Report_Guidelines.md` exactly. Audience: classmates + professor (academic report).
Framing: a solution for an **e-commerce / product manager** to understand attribute-level sentiment and gaps.
Confirm the plan with the user before writing.

## 2. Read first
| File | What |
|---|---|
| `Big_Data_Project_Report_Guidelines.md` | Mandatory structure, page limits, format, checklist |
| `REPORT_NOTES.md` | Technical facts: data, architecture, methodology, results, limitations |
| `TEAM_BRIEF.md` | Plain-language version + glossary |
| `output/subcategory_regression_top2_v2.txt` | R `summary(model)` + correlation matrices for top-2 subcategories |
| `processing/subcategory_regression.R` | Regression + selection + correlation code |
| `main.R`, `constants.R`, `setup.R`, `utils.R`, `processing/*.R`, `models/bert_sentiments.R` | Pipeline code |
| `output/attribute_df_v2.csv`, `output/product_attribute_df_v2.csv`, `output/review_sentence_aspect_v2.csv` | v2 pipeline outputs (use ONLY _v2 files) |
| `datasets/final_reviews.csv`, `datasets/final_attributes.csv` | Input data + attribute dictionary |

## 3. Decisions already made by the user
- Format: **Word .docx**, written in local MS Word (computer use).
- Formatting: double-spaced, ≥1" margins, ≥11 pt (use 12 pt Times New Roman or Calibri), page numbers, cover page + TOC.
- Length: main report ≤25 pages (target 24) excl. appendices. Cover/TOC page-counting rule → [TO CONFIRM with professor].
- Citations: **IEEE** (numbered [1]). Literature review: search the web; **real, verifiable sources only**, no invented references.
- Data source: **Amazon Reviews 2023, McAuley Lab (Hou et al., 2024)**, Electronics category.
- Subcategories (22) were assigned using **AI (LLM-assisted) categorisation**. How the 30,740-review sample was drawn and the time period → [TO CONFIRM].
- Cover page: placeholders → [Project Title], [Team Members], [Course Code], [Professor], [Date].
- Results section includes: **EDA descriptives**, **top-2 subcategory regressions (cables, peripherals)**,
  **multicollinearity check**, **product-level score card example**.
  **Do NOT include the pooled all-reviews regression.**
- Figures: **regenerate with R/ggplot2 from v2 data**; add script `processing/report_figures.R`; save PNGs to `output/graphs/report/`.

## 4. Report structure and page budget (from guideline)
| # | Section | Pages | Main content source |
|---|---|---|---|
| 1 | Executive Summary | 1 | Written last |
| 2 | Introduction & Business Problem | 2 | REPORT_NOTES §1 + PM framing, research questions, scope, use cases |
| 3 | Literature Review & Analytical Background | 2 | Web search (see §6) |
| 4 | Data Description & Preparation | 3 | REPORT_NOTES §2, §4 steps 1–2, EDA |
| 5 | Methodology & System Architecture | 5 | REPORT_NOTES §3–4; architecture + workflow diagrams; regression spec, selection rule, correlation check |
| 6 | Results & Analysis | 5 | REPORT_NOTES §5 (descriptives, top-2 regressions, multicollinearity, score card) |
| 7 | Discussion & Business Implications | 2 | REPORT_NOTES §6 + PM use cases, literature comparison |
| 8 | Limitations & Future Improvements | 2 | REPORT_NOTES §7 expanded (ethics, scalability, validation) |
| 9 | Conclusion & Recommendations | 1 | Prioritised, evidence-based |
| 10 | References | 1 | IEEE |

Appendices: A data dictionary · B preparation/cleaning rules · C code excerpts + config (thresholds, model IDs) ·
D extra results (full attribute table) · E model evaluation (full R summaries + correlation matrices) ·
F expanded architecture/pipeline · G attribute dictionary per subcategory.

## 5. Key verified facts (all from v2 outputs)
**Data:** 30,740 reviews (30,738 after sentence split) · 17,452 products · 22 subcategories · 84,342 sentences ·
ratings 1★ 2,818 / 2★ 1,155 / 3★ 1,612 / 4★ 3,227 / 5★ 21,928 (71% 5★) · 96.4% verified ·
dictionary 1,528 rows, 60 attributes, 6–8 per subcategory.

**Pipeline:** R throughout; Python only for pretrained transformer (reticulate).
Sentence split (tokenizers) → 3-sentence context window (prev+cur+next, same review) →
aspect detection limited to the review's subcategory: (a) lexical n-gram exact match; (b) fastText cc.en.300
cosine similarity ≥ 0.30 and margin ≥ 0.05 over 2nd-best; dictionary expanded with top-70 fastText neighbours,
sim ≥ 0.59 → DeBERTa-v3 ABSA `sy12ssss/absa-deberta-v3` (aspect, window), max 256 tokens →
score = P(pos) − P(neg) ∈ [−1, 1] → per review×attribute: attribute_score (mean), attribute_count,
attribute_coverage = count / total sentences → product×attribute summary.
Efficiency: models loaded once; embeddings cached as RDS; per-subcategory caches; transformer called only where an aspect was detected.

**Descriptives:** 61,422 sentences (72.8%) have ≥1 attribute · 26,405 reviews (85.9%) · 68,013 mentions,
71.1% positive / 28.9% negative, median score 0.97 (bimodal).
Top attributes (mentions, mean, % neg): build 7,131 / 0.48 / 24% · durability 7,099 / 0.55 / 22% ·
fit 5,650 / 0.44 / 27% · sound 5,571 / 0.47 / 26% · battery 3,159 / 0.30 / 34% · connectivity 3,146 / 0.18 / 40% ·
comfort 2,291 / 0.74 / 12%.
Pain points: noise −0.15 (58% neg), detection, claims, cost, heat, alerts.
Mean rating by # attributes discussed: 0→4.60, 1→4.41, 2→4.30, 3→4.21, 4→4.14, 5→4.10, 6→3.98, 7→3.85.
Very negative mean score: 46% 1★ / 8% 5★; very positive: 0% 1★ / 91% 5★.

**Regression:** per subcategory, `lm(rating ~ .)`: score + coverage for EVERY dictionary attribute
(unmentioned → 0; zero-detection attributes kept; none exist in v2). All 22 fitted; top 2 chosen by
mean of rank(adj R²) and rank(share of predictors p < 0.05).
- **Cables:** n = 3,149, adj R² 0.5575, F = 284.3, 11/14 significant. Fit score 0.726***, charging 0.670***,
  length 0.262***, durability 0.218***, speed 0.184**, compatibility 0.133**, connectivity 0.131**;
  coverage: charging −0.593***, fit −0.512***, length −0.337***, durability +0.115*.
- **Peripherals:** n = 849, adj R² 0.5506, F = 75.2, 10/14 significant. Build score 1.096***,
  performance 0.364***, battery 0.242**, controls 0.226*, compatibility 0.220*, connectivity 0.215*;
  coverage: build −0.938***, performance −0.542**, compatibility −0.401*, comfort +0.358**.
- **Multicollinearity:** max |r| cables 0.530 (charging vs fit score); peripherals 0.677
  (comfort score vs comfort coverage) → all < 0.7, no serious multicollinearity.
- **Interpretation:** positive feeling raises rating; greater coverage (given feeling) lowers rating
  (customers elaborate on problems); drivers differ by subcategory.

**Score card example:** `product_attribute_df_v2.csv` (e.g. security camera B07VTK654B: 36 of 45 negative on one attribute).

## 6. Literature to find and cite (IEEE)
ABSA / SemEval (Pontiki et al. 2014, 2016) · BERT (Devlin 2019) · DeBERTa / DeBERTa-v3 (He et al.) ·
fastText (Bojanowski 2017) · GloVe (Pennington 2014) · Amazon Reviews 2023 (Hou et al. 2024) ·
review text vs star rating / aspect ratings · negativity bias / review elaboration · OLS & multicollinearity
thresholds · R, reticulate, Hugging Face docs, the `sy12ssss/absa-deberta-v3` model card.

## 7. Figures to generate (`processing/report_figures.R`)
F1 rating distribution · F2 reviews per subcategory · F3 attributes per review · F4 mean rating vs # attributes ·
F5 mention volume + % negative per attribute · F6 rating mix by sentiment bin · F7/F8 coefficient plots with
95% CI (cables, peripherals) · F9 correlation heatmaps · F10 product score card example ·
system architecture diagram · workflow diagram.

## 8. Limitations to state
71% 5★ skew · OLS on ordinal target (ordered logit as a check) · score/coverage linked · no human-labelled validation ·
heuristic thresholds · window overlap not de-duplicated · "build" is broad · small subcategories ·
single sample run · sequential transformer inference is slow · AI-assigned subcategories may be misclassified.

## 9. Verification before finishing
Main body ≤25 pages · double spacing, margins and font checked · every [n] cited ↔ listed ·
numbers match v2 outputs / R output · figures/tables numbered with titles + source notes ·
[TO CONFIRM] items listed for the team · guideline §7 checklist completed.
