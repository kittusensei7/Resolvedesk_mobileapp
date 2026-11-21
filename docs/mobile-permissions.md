# Mobile permissions

Maintained 29 October 2026. The app uses the same **user + Technician workspace + feature + action** grants as the web. There is no mobile permission database or second permission editor.

## Current behavior

| Mobile area | Existing grant |
|---|---|
| Dashboard and assigned complaint reads | `tech_dashboard.view` |
| Complaint actions | Dashboard View plus `service_calls.edit` OR `complaints.edit`; server assignment rules still apply |
| Service report list/forms | `service_calls.view/add/edit/delete` as appropriate |
| Installation list/forms | `installations.view/add/edit/delete` as appropriate |
| Enquiries/list/submission | `enquiries.view/add` as supported by the current UI |

The shared Provider controller loads `GET /api/permissions/my-permissions`, shares pending loads, refreshes on resume and every 15 seconds while foregrounded, and pauses polling in the background. Permission-load failures pause protected content with Retry. No broad role or legacy superadmin fallback enables screens.

View removal hides the screen/content, clears fetched lists/details and cancels obsolete reads. Late responses cannot restore revoked data. Add/Edit removal leaves an unsaved draft in memory, with disabled inputs/actions and a scrollable form. Restoring access re-enables permitted actions. Closing a form discards its local draft; no offline storage or queued writes were added. A replacement session cannot display or submit a previous account's open form.

Structured 403 `PERMISSION_DENIED` refreshes access once per burst without logging out or retrying the rejected write. Ordinary ownership/validation denials remain ordinary errors. 401 still expires the session; old-session 401 responses cannot clear a newer login. Save/Delete/complaint actions recheck access before sending. Notification entry checks permission and session before opening Complaint Details.

Global permission revision changes no longer recreate the active tab. Existing Technician/Sales separation remains: this technician app requests Technician workspace for dual accounts. Removing Sales Enquiries does not remove Technician/mobile Enquiries.

Call Reports, Quotations and Purchase Orders are not mobile screens in this release. A backend grant does not create a Flutter screen.

## Code responsibilities

- `lib/services/permission_access.dart`: parse and query the existing permission response.
- `lib/services/permission_controller.dart`: session state, shared refresh, freshness and lifecycle.
- `lib/widgets/permission_guard.dart`: protected content, read cancellation/generation checks and read-only form sections.
- App bootstrap/API configuration: attach the shared provider and clear access on session changes.
- Existing pages/forms: apply feature/action guards without replacing their business workflows.
- Notification and signature handling: recheck access/session after asynchronous operations.

No backend files, SQL tables, grants, dependencies, version numbers or published APKs are changed by this implementation.

## Automated verification

From the mobile checkout with a working Flutter SDK:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Tests use injected responses and transport adapters, not production accounts. They cover parsing, shared loads, refresh failures, lifecycle polling, session cleanup, direct/notification access, stale reads, draft preservation, grant/revoke refresh behavior, Add-only lookups, mid-confirmation removal, structured 403/401 behavior and layout checks. A normal test run does not contact the backend or send notifications.

Verification recorded on 29 October 2026:

| Check | Result |
|---|---|
| Complete Flutter test suite | **30 passed, 0 failed**: six access, six controller, seventeen permission UI and one bootstrap test |
| `dart analyze lib test` | **No issues found** |
| `flutter analyze --no-pub` | **No issues found** |
| `flutter build apk --debug --no-pub` | **Passed** for the final implementation; test artifact only |
| Permission-state layouts | No Flutter overflow exceptions at 390px and 1024px |
| Independent real-font visual review | All seven axes met at least 4/5 after native disabled styling was added |
| Real device / isolated-backend acceptance | **Pending**; not established by mocked widget tests |

The existing Firebase Kotlin-plugin forward-compatibility warning remains during Android builds. The first cold build also emitted existing Android SDK XML/Java/deprecation warnings; no build-system/dependency upgrade is included here. Real-font permission-state captures were reviewed at 390px and 1024px; this is not a claim that every screen/state has been visually reviewed on a device.

Local tooling note: the installed Flutter SDK was missing its Dart launcher. Verification uses an external temporary toolchain assembled from existing SDK files; the installed SDK is not repaired or replaced by this feature. Resolve the normal SDK installation before relying on its usual `flutter` command.

## Required device acceptance before release

Use a backend configured for the restored isolated test database and deliberately safe SMTP/push settings. Do not point mutation tests at production. Background-worker disabling alone does not block explicit API notification producers.

1. Grant/remove an existing feature for one technician; verify both web and app after refresh.
2. Repeat group addition/removal/restoration with pure and dual technicians; check Sales workspace stays independent.
3. Verify View-only and each supported action separately, including deleting after its confirmation is opened.
4. Remove Add/Edit with a draft open; verify disabled controls, scrolling and preserved text. Restore access; saving becomes available again.
5. Remove View or every mobile feature; verify no stale records, a clear restriction/no-access state and logout.
6. Test slow/offline refresh, Retry, app background/resume, account switching and notification entry.
7. Verify complaint assignment restrictions and normal report/enquiry workflows remain intact.

The debug APK is a compilation/test artifact, not the production release. Keep the existing published APK. After acceptance, choose the next version, use the approved signing configuration, build a release APK and publish through the existing process. Production asset replacement, release version changes and device acceptance are not performed automatically.
