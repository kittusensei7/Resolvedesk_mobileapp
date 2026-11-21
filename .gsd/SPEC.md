# Mobile reports UI and Call Reports

Status: FINALIZED

Approved through the user's 30 October 2026 implementation request.

- Improve service report form/list, searchable complaint selection and phone/PDF preview layouts.
- Preserve the current Complaint Details -> Problems Found/Action Taken/Remarks prefilling, saved records and API field selection.
- Correct application-owned mojibake only, never rewrite customer data.
- Add mobile Call Reports list, organization grouping/history, create/edit/delete and follow-up workflow through existing APIs and Technician-workspace call_reports permissions.
- Reuse shared permission refresh, request cancellation, session isolation and draft preservation; no new permission system.
- Tighten existing Call Reports detail/history owner/workspace read restrictions without changing authorized manager reporting or legacy NULL visibility.
- Normal service PDFs remain A4; long reports may continue on further readable A4 pages.
- Reuse existing design system; independent rendered visual review; no new dependencies, data migrations or publication.
- At the user's request, do not create or run automated tests. Static analysis/build and rendered inspection are allowed; provide manual device acceptance steps.
- Do not commit or publish automatically. Keep the existing APK for recovery.
