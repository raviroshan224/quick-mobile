# Quick Mobile — Complete Technical Documentation

**Quick** is a Flutter point-of-sale (POS) app for beauty & wellness businesses in Nepal — salons, spas, barbershops, nail studios, parlors. It talks to `Quick-be` (NestJS, `https://api.quick.com.np`), the same backend the companion web app (`quick-web`) uses.

This document is exhaustive by design: every model's fields, every repository method's exact endpoint, and every screen's actual UI/UX — not summaries. It exists so that `quick-web` (or any other client) can be built to genuine feature parity, and so the app's real behavior is documented somewhere other than the source itself.

---

## 1. Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart), Material 3, `useMaterial3: true` |
| State management | Riverpod 2.5 (`flutter_riverpod`) + `hooks_riverpod`/`flutter_hooks` for widget-local ephemeral state |
| Routing | `go_router` 14.2 |
| HTTP | `dio` 5.4, layered interceptor stack |
| Token storage | `flutter_secure_storage` 9.2 (native Keychain/Keystore on mobile/desktop; browser `localStorage` + WebCrypto AES-GCM on web — see §11 for a real bug found in the web path) |
| Package ID | `com.salonpos.salon_pos` |

**Platforms**: all six standard Flutter targets are present and populated — `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`. The UI is mobile-first (persistent bottom tab bar) with a responsive split-panel fallback on wide screens, used only by the auth flow.

- **Android**: Gradle flavors `dev`/`staging`/`prod` (application-ID suffixes on dev/staging, none on prod), Java/Kotlin target 17. **Release builds currently sign with the debug key** — not production-ready for a real Play Store release as-is.
- **iOS**: standard `Runner` Xcode project/workspace + `RunnerTests` target.
- **Web**: works, but requires two things not needed on native platforms — see §12 (running on web).
- **App icon**: generated via `flutter_launcher_icons` from a single source image, adaptive-icon background `#0F172A`.

**Env/base URL**: `lib/core/utils/env_config.dart` defines `Flavor.dev|staging|prod`; dev and staging currently both point at the same production API (`https://api.quick.com.np`) — there is no separate dev/staging backend deployed yet. Selected via the `USE_PROD_API` compile-time flag, defaulting to `kReleaseMode`.

---

## 2. Architecture

**State management**: Riverpod throughout. Patterns used: plain `Provider` (repository/DI wiring — one `xRepoProvider` per feature, each just `Provider((ref) => XRepository(ref.read(apiClientProvider)))`), `FutureProvider`/`FutureProvider.family`/`FutureProvider.autoDispose` (read-only async data), `StateNotifierProvider` (complex mutable flows — auth, bookings, cash drawer, discounts, image library, reports, refund history), `Notifier`/`NotifierProvider` (Riverpod 2's class-based notifier — the cart), and `StateProvider` for trivial UI state (search queries, tab selection). No code generation despite `riverpod_annotation`/`riverpod_generator` being declared dependencies — every provider is hand-written.

**Routing**: single `routerProvider` in `lib/core/router/app_router.dart`. Non-shell routes: `/splash`, `/profiles`, `/login`, `/signup`, `/verify-otp`, `/forgot-password`, `/reset-password`. A `ShellRoute` wraps `MainShell` around the 4 tab roots (`/dashboard`, `/checkout`, `/transactions`, `/notifications`... — see §5) plus ~25 `/more/*` sub-routes. The `redirect` callback implements, in order: unauthenticated → `/login`; OTP-pending → `/verify-otp`; password-reset-pending → `/reset-password`; owner-with-no-profile-selected → `/profiles`; **role-gated routes** — staff are redirected away from a hardcoded owner-only list (`setup-guide`, `services`, `items`, `discounts`, `staff`, `reports`, `settings`, `image-library`, `stock-movement`) back to `/more`. This is a real router-level authorization boundary, not just hidden UI. `_RouterRefresh` (a small `ChangeNotifier`) bridges the auth `StateNotifier` into GoRouter so these guards re-evaluate live on auth-state changes.

**Folder structure**: feature-first (`lib/features/<name>/`). Convention inside each feature is inconsistent — most use `data/` + `domain/` + `presentation/{providers,screens,widgets}/`; a few (discounts, and several dead/legacy ones) use a flatter `data/models/providers/screens/widgets` layout. `lib/core/` holds cross-cutting concerns (network, router, storage, theme, constants, utils, shared widgets); `lib/shared/widgets/` holds reusable UI (`MainShell`, stat cards, search fields, empty states, dialogs).

**Important structural quirk — duplicate dead screens**: many features have a *second*, unreferenced copy of their screens sitting in the feature's own folder, while the actual router-wired version lives under `lib/features/more/presentation/screens/`. Confirmed dead (never imported anywhere): `auth/screens/login_screen.dart`; the entire `items/` and `products/` features (superseded by `inventory/` + `more/items_screen.dart`); `staff/models/staff_model.dart` + `staff/presentation/screens/{add_edit_staff_screen,staff_detail_screen,staff_list_screen}.dart`; `cash_drawer/models/cash_drawer_model.dart` + `cash_drawer/presentation/screens/cash_drawer_screen.dart`; `refunds/presentation/screens/refunds_screen.dart`; `reports/screens/reports_screen.dart` + `reports/providers/reports_provider.dart`; `settings/screens/settings_screen.dart`; `notifications/screens/notifications_screen.dart`; `inventory/presentation/screens/inventory_list_screen.dart`; `image_library/presentation/screens/image_library_screen.dart`. **Exception**: for Discounts, the feature's *own* `discounts/screens/` folder is the live one (not `more/`). Worth a cleanup pass at some point — this table documents only the live versions.

---

## 3. Design system (`lib/core/theme/app_theme.dart`)

This is the single source of truth `quick-web`'s design was rebuilt from — every value below is used verbatim there too.

**Colors** (`AppColors`):
- Brand: `primary` olive `#6B7A3D`, `primaryDark` `#4D5A2C`, `primaryLight` `#F0F2E8`.
- Dark panels: `sidebarBg` `#111111`, `sidebarHover`/`sidebarActive` `#1C1C1C`, `sidebarText` `#9A9A9A`, `sidebarDivider` `#2A2A2A` — used for the auth screens' brand panel. **Not used for an in-app desktop shell** — `sidebarWidth`/`cartPanelWidth`/`topBarHeight` constants exist in `AppSpacing` but no widget in `lib/` actually uses them; the app reuses the same bottom-nav `MainShell` at every screen width. (`quick-web` is what actually implements the desktop shell these tokens were seemingly meant for.)
- Neutrals: `background`/`surface` white, `surfaceVariant`/`cardBg` `#F8F8F5`, `textPrimary` `#111111`, `textSecondary` `#5A5A5A`, `textTertiary` `#9A9A9A`, `textHint`/`border`/`divider` `#BBBBBB`/`#D9D9D9`.
- Semantic: `success` `#10B981`, `warning` `#F59E0B`, `danger` `#EF4444`, `fonepayColor` `#6BBD44` (Fonepay's own brand green, kept as-is).

**Typography** (`AppTextStyles`): full scale from `displayLarge` (36/800) down to `labelSmall` (11/500), plus POS-specific `priceTag` (16/700) and `kpiValue`/`kpiLabel`. `fontFamily: 'SF Pro Display'` is declared at the theme level but no font asset is bundled — it silently falls back to each platform's system sans (SF Pro on iOS, Roboto on Android). Effectively "clean system font," not a real webfont dependency.

**Spacing** (`AppSpacing`): 4/8/12/16/20/24/32 scale; `pagePadding` 24, `cardPadding` 16, `listItemPadding` 16h/12v; `sidebarWidth` 220, `cartPanelWidth` 340, `topBarHeight` 60 (unused, see above).

**Radius** (`AppRadius`): sm 6, md 10, lg 14, xl 18, xxl 24, pill 100.

**Shadows** (`AppShadows`): `card`/`elevated`/`dialog` defined, but component themes mostly favor a **flat, bordered** look over shadows — `CardThemeData` uses `elevation: 0` with a real 1px `divider`-colored border.

**Component theming highlights**: inputs are filled (`surfaceVariant` bg), 10px radius, grey border, and — deliberately — focus border is **black**, not olive (a neutral/minimal choice; only OTP-style boxes and a few other specific inputs use an olive focus ring). Buttons are olive-filled, white text, 10px radius, 48px min height. Chips are pill-shaped, filled, bordered. Bottom sheets get a 20px top radius with a visible drag handle. Many admin/CRUD screens (Services, Items, Stock Movement) deliberately use **black**, not olive, for selected-chip states and primary save buttons — a secondary neutral accent distinct from the olive brand color used for marketing/checkout CTAs.

---

## 4. Auth & session model

- **`splash_screen.dart`** checks stored auth on boot, routes to login / profile-picker / dashboard.
- **`login_screen.dart`** — owner-only email+password login. Responsive: **≥700px** → dark brand panel (logo, "Quick" wordmark, tagline, 4 feature bullets with olive icon chips) + fixed 440px white form panel; **<700px** → centered white rounded card on the dark background, logo above it. `signup_screen.dart`, `forgot_password_screen.dart`, and `reset_password_screen.dart` all reuse this exact wide/narrow pattern (each has its own local copy of `_BrandPanel`/`_Logo`, not a shared widget). `otp_screen.dart` is the one exception — narrow-only, no brand panel, with 6 individual auto-advancing digit boxes (44×52, olive focus ring, auto-submits at 6 digits).
- **`signup_screen.dart`** — first/last name (side-by-side), email, password → OTP verification. Backend allows exactly one OWNER account ever; signup is blocked after that.
- **Profile switching / PIN login** (`profile_picker_screen.dart`) — the shared-till, multi-staff answer: an **owner logs in once** with email+password; the app persists a long-lived owner session in `flutter_secure_storage` under separate `owner_access_token`/`owner_refresh_token` keys. Switching to a staff profile (grid of profile cards → 4-digit PIN sheet) calls `POST /auth/pin-login` and swaps the active session without discarding the stored owner credentials — `AuthNotifier.switchProfile()` can restore the owner session later with no password re-prompt.
- **`AuthNotifier`/`AuthState`** drives a 10-state `AuthStatus` enum (including `pickingProfile`, `pendingOtp`, `resetPending`); `_RouterRefresh` bridges it into GoRouter for live route re-evaluation.
- **Staff creation** is a 3-step flow driven from the Staff feature, not a self-serve signup: `POST /auth/register` (creates the underlying user with a random, never-used password) → `POST /staff` (creates the staff record, links `userId`) → `PATCH /auth/staff/:id/pin` (sets their PIN). See §5.7.

---

## 5. Navigation & app shell

**`MainShell`** (`lib/shared/widgets/main_shell.dart`): 52px top bar (28px logo + "Quick" wordmark, 17px/700), 4-tab `BottomNavigationBar` — **Dashboard** (`home`), **Checkout** (`grid_view`), **Transactions** (`swap_horiz`), **More** (`menu`, red badge = count of failed notification deliveries). Olive when active, `textTertiary` grey when not, 10px labels, `elevation: 0`. Notifications (`/notifications`) is a real top-level route but is *not* one of the 4 tabs — it's reached only via the badge/menu, not the bottom bar itself.

Under `/more/*`: ~25 sub-routes covering every feature in §6 below (list/new/edit/detail per feature as applicable), plus `setup-guide`, `support`, `privacy-policy`, `terms`, `my-profile`.

---

## 6. Feature reference

Each entry: exact model fields, exact repository → endpoint mapping, and exact screen UX. "Live screen" = the one actually wired in the router (see the dead-code note in §2 — not repeated per feature below).

### 6.1 Dashboard
`dashboard/data/dashboard_repository.dart` → `GET /dashboard` (single aggregated call). `DashboardSummary`: `todaySales, todayTips, todayTransactionCount, customersServedToday, topStaff (list), lowStockAlerts (list), cashDrawer (open/balance)`. Screen: `more/presentation/screens/dashboard_screen.dart`.

### 6.2 Checkout / POS
4-segment screen (`checkout_screen.dart`): Keypad, Calendar (§6.11), Services, Items. Cart state (`pos/domain/pos_models.dart`): `CartItem`, `CartState` (client-computed subtotal/discount/total), `DiscountEntry` (`DiscountEntryScope.all|service`), owned by `CartNotifier` (`Notifier`-based). `review_sale_sheet.dart` is the payment bottom sheet (cash/Fonepay QR/split, tip, discount, guest-or-customer). `widgets/manual_discount_sheet.dart` lets a cashier type an ad-hoc discount. Post-checkout: `pos/presentation/screens/receipt_screen.dart` (`/checkout/receipt`).

### 6.3 Transactions
`transaction_models.dart`: `Transaction`, `TransactionItem` (snapshots service/staff names so historic receipts survive later renames), `RefundRecord`/`RefundedItem` (see §6.10). Screens: `transactions_screen.dart` (filterable list), `transaction_detail_screen.dart` (line items, refund entry point, staff attribution).

### 6.4 Services & Categories
`service_models.dart`: `ServiceCategory {id, name, isActive}`; `ServiceModel {id, name, price, duration (int, minutes — 0 = unset), description?, category (ServiceCategory?), iconUrl?, isActive=true}`, computed `durationLabel`/`priceLabel`.
Repo (`services_repository.dart`): `getCategories()` → `GET /services/categories`; `createCategory(name)` → `POST /services/categories` `{name}`; `getServices({categoryId?, isActive=true})` → `GET /services?limit=100&isActive&categoryId`; `getById(id)` → `GET /services/:id`; `create({name, price, duration, description?, categoryId?, isActive=true})` → `POST /services`; `update(id, {...})` → `PATCH /services/:id`; `delete(id)` → `DELETE /services/:id`.
List screen (`more/services_screen.dart`): search bar, horizontal category chips (All + each category, black when selected), item count, 3-col grid of cards colored per-category (via a hardcoded id→color map — cosmetic only, doesn't reflect real category ids), name + price. Owner-only add (+) and tap-to-edit. Form (`more/service_form_screen.dart`): preview card (icon picker via `ImagePickerSheet`, name, category, price, active badge); sections SERVICE DETAILS (name*, category dropdown + inline "create category" button, description), PRICING (price*), STATUS (active toggle). **Duration is not actually exposed in the form UI** despite existing in the model/DTO — create always sends `duration: 0`, edit never updates it. Delete icon in app bar (edit mode) → confirm dialog.

### 6.5 Products / Inventory
`inventory_models.dart`: `ProductModel {id, name, price, stock, description?, sku?, cost?, lowStockThreshold=5, category?, imageUrl?, isActive=true}`, computed `isLowStock` (`stock <= lowStockThreshold`), `priceLabel`. `InventoryMovementType {stockIn, stockOut, adjustment}`. `InventoryLogEntry {id, productId, productName, type, quantity, reason, stockBefore, stockAfter, createdAt, createdByName?}`.
Repo (`inventory_repository.dart`): `getProducts({lowStock?})` → `GET /products?limit=100&isActive=true[&lowStock=true]`; `getById(id)` → `GET /products/:id`; `create(...)`/`update(...)` → `POST`/`PATCH /products[/:id]` (name, price, stock, cost?, sku?, description?, category?, lowStockThreshold=5, isActive); `delete(id)` → `DELETE /products/:id`; `searchProducts(query)` → `GET /products?search=&limit=10&isActive=true`; `recordMovement({productId, type, quantity, reason})` → `POST /inventory/movement` `{productId, type: 'STOCK_IN'|'STOCK_OUT'|'ADJUSTMENT', quantity, reason}`; `getLogs`/`getLogsPaginated` → `GET /inventory/logs?page&limit[&type]`.
List screen (`more/items_screen.dart`): same pattern as Services but category is a **free-text string** (real, functional color map keyed by category name — unlike Services' fake id-based one). Cards additionally show stock status ("Low stock · N" in red, or "N in stock" in grey). Form (`more/item_form_screen.dart`): sections Basic Information (name*, SKU), Pricing (selling price*, cost price), Inventory (stock quantity*, low-stock threshold), Details (category, description), Status (active toggle, edit-mode only). **No delete button in this form** — unlike Services, Items can't be deleted from the edit screen.
Stock Movement (`more/stock_movement_screen.dart`, ~1300 lines, the most complex screen in the app) — 2 tabs: **Record** (movement-type 3-way toggle [Stock In/Out/Adjustment, each with its own icon+color], debounced product search-autocomplete, quantity input, reason preset chips [different per type: Purchase/Return/Adjustment for in; Damaged/Expired/Theft/Adjustment for out; Stock Count/Correction/Write-off for adjustment] + free-text override, live current→new-stock preview card, black submit pill "Record Movement"); **History** (infinite-scroll log list, each row: product name, type badge, ±qty in type color, stockBefore→stockAfter, reason, timestamp + who).

### 6.6 Customers
`customer_models.dart`: `CustomerModel {id, firstName, lastName, email?, phone?, notes?, photoUrl?, visitCount=0, totalSpent=0, lastVisitDate?}`, computed `fullName`, `initials`, `lastVisitLabel` (Never/Today/Yesterday/"Nd ago"/"Nw ago"/"Nmo ago"). Note: `fromJson` never actually parses `lastVisitDate` from the API — it's always null as currently coded, a latent bug.
Repo (`customers_repository.dart`): `getAll({query, page=1, limit=100})` → `GET /customers?page&limit&search` (paginated); `getById` → `GET /customers/:id`; `create({firstName, lastName, email?, phone?, notes?})` → `POST /customers`; `update(id, {...})` → `PATCH /customers/:id` (sparse — only sends provided fields); `delete(id)` → `DELETE /customers/:id`.
List (`more/customers_screen.dart`): search bar, alphabetically-sectioned list (A–Z headers by first name), each row: initials avatar, full name, phone-or-email subtitle, "N visits" + "Rs Xk" trailing, chevron. "+" → new. Detail (`customer_detail_screen.dart`): hero (avatar, name, phone/email, notes card), 3 stat cards (Visits, Total Spent, Last Visit), visit history (past transactions), "Start Sale" → checkout. Form (`customer_form_screen.dart`): preview card with image picker; sections NAME (first*, last*), CONTACT (phone — digits only, email — regex-validated), NOTES (multiline). Delete icon (edit mode) → confirm. **Permission gate**: if the salon's `staffCanViewCustomerDetails` setting is off and the current user is staff (not owner), Phone/Email/Notes fields are disabled with hint "Hidden — ask the owner" instead of showing real data.

### 6.7 Staff
`staff_models.dart`: `StaffModel {id, userId, email?, firstName, lastName, phone?, specialties=[], commissionRate?, photoUrl?, isActive=true}` — `firstName`/`lastName`/`email` read from a nested `user` object first, flat fields as fallback.
Repo (`staff_repository.dart`): `getAll({activeOnly=false})` → `GET /staff?limit=100[&isActive=true]`; `getById` → `GET /staff/:id`; **`createWithAccount(...)`** — a 3-call sequence: `POST /auth/register {email, firstName, lastName, password}` (password is a locally-generated random 12-char string the staff member never uses — email auto-derived as `${firstname}${lastname}${phone}@quickpos.staff` if not supplied) → `POST /staff {userId, phone?, specialties, commissionRate?, emergencyContact?, emergencyContactName?, emergencyRelationship?, address?, govIdType?}` → `PATCH /auth/staff/:id/pin {pin}`; `update(id, {phone?, specialties?, commissionRate?, isActive?, emergencyContact?, emergencyContactName?, emergencyRelationship?, address?})` → `PATCH /staff/:id`; `delete` → `DELETE /staff/:id`. PIN reset for an *existing* staff member goes through `AuthRepository.setStaffPin(id, pin)` → `PATCH /auth/staff/:id/pin` (called from the form, not this repo).
List (`more/staff_screen.dart`): search (name/specialty), Active/Inactive segmented tabs, cards with a cycling 8-color avatar palette, name + active-dot, up to 3 specialty chips, commission-% badge (only if commission tracking is enabled in settings and the staff has a rate). Detail (`staff_detail_screen.dart`): profile card, stat cards (Recent Sales, Commission [if enabled], Services count), recent-activity list → "View All" → **`staff_history_screen.dart`** (infinite-scroll, day-grouped transaction history for that one staff member). Form (`staff_form_screen.dart`) — the most field-heavy form in the app, in order: preview card; Basic Information (name*, mobile*, email [readonly+locked once created]); Emergency Contact (number/name/relationship, all optional); Address; Government ID (type toggle: Citizenship/Passport/Driving License + photo upload); Commission (rate 0–100%, only if commission tracking enabled); Specialties (12 predefined toggle chips: Haircut, Hair Color, Blow Dry, Facial, Manicure, Pedicure, Nail Art, Waxing, Massage, Threading, Makeup, Keratin); Status (active toggle); Sign-in PIN (create mode: PIN + confirm, must match; edit mode: "Set PIN" button → dialog); Activity summary + Danger Zone → Remove Staff Member (edit mode only).

### 6.8 Discounts
`discount_model.dart` (not in a `domain/` folder — flat layout): `Discount {id, name, type (DiscountType: percentage|fixed), value, isActive=true, scope (DiscountScope: all|service)=all, serviceId?, serviceName?}`, computed `label` ("10% off"/"Rs 100 off"), `scopeLabel`, `apply(subtotal)`.
Repo (`discounts_repository.dart`): `getAll()` → `GET /discounts?limit=100`; `findByCode(code)` → `GET /discounts/code/:code`; `create({name, type, value, isActive=true, code?, scope=all, serviceId?})` → `POST /discounts` `{..., type: 'PERCENTAGE'|'FIXED', scope: 'ALL'|'SERVICE'}`; `update`/`delete` accordingly.
List (`discounts/screens/discounts_screen.dart` — one of the few features where the feature's own folder, not `more/`, is live): Active/Inactive sections with counts, type-icon rows (percent/rupee), name + "Percentage/Fixed · scope" + value. **Owner-only** — staff see a read-only list (no tap, no add button), with a footer note "Staff can apply one discount per transaction from the checkout Library tab." Form (`discount_form_screen.dart`): preview card; Details (name*); Discount Type (Percentage/Fixed toggle); Value (validated required, >0, ≤100 if percentage); Applies To (two tiles: All services & items / Specific service — the latter opens a searchable service picker sheet); Visibility (active toggle). Delete (edit mode) → confirm; if the deleted discount is currently applied in the cart, it's cleared automatically. Checkout-side consumer: `discount_picker_sheet.dart` — "Apply Discount" sheet with a "Manage" link back to this screen, a manual-entry option, and the active-discount list filtered to hide service-scoped discounts whose service isn't in the current cart.

### 6.9 Cash Drawer
`cash_drawer_models.dart`: `CashMovementType {cashIn, cashOut}`; `CashMovementEntry {id, type, amount, reason, createdAt, transactionId?}`; `CashDrawerSession {id, openBalance, openedAt, movements, closeBalance?, closedAt?, notes?}`, computed `isOpen`, `totalIn`, `totalOut`, `currentBalance`, `discrepancy`.
Repo (`cash_drawer_repository.dart`): `getCurrent()` → `GET /cash-drawer/current` (null if none open); `open(openBalance, {notes?})` → `POST /cash-drawer/open`; `close(drawerId, closeBalance, {notes?})` → `POST /cash-drawer/:id/close`; `recordMovement({drawerId, type, amount, reason})` → `POST /cash-drawer/:id/movement` `{type: 'IN'|'OUT', amount, reason}`.
Screen (`more/drawers_screen.dart`, titled "Drawers") — simplest UI in the app, plain `AlertDialog`s rather than custom sheets. **Closed state**: "No open drawer" + Open Drawer button → dialog (opening balance, notes). **Open state**: black hero balance card ("Current Balance" + "+Rs X in"/"-Rs Y out" pill chips), Pay In / Pay Out buttons → dialog (amount, reason), movements list below (in/out icon, reason, time, ± amount). **Note**: the repository supports `close()` but no close-drawer action was found wired into this screen's visible UI — closing a drawer may be missing from the UI entirely, or handled elsewhere not covered by this file.

### 6.10 Refunds
No dedicated domain — `RefundRecord`/`RefundedItem` live in `transactions/domain/transaction_models.dart`; refund methods live in `TransactionsRepository`. `RefundedItem {id, quantity, unitPrice (derived: amount/quantity, since the API's line only has a total `amount`), displayName?}`; `RefundRecord {id, transactionId, amount, reason, createdAt, receiptNumber?, customerName? (falls back to guestName), processedByName?, items?}`.
Repo methods: `refund(id, {amount, reason})` → `POST /transactions/:id/refund` (older/simpler whole-or-partial cash refund); `createRefund(transactionId, dto)` → `POST /refunds/:transactionId` `{reason, items: [{transactionItemId, quantity}]}` (the actual item-level refund flow, initiated from transaction detail); `getRefundHistory({page, limit})` → `GET /refunds?page&limit`.
Screen (`more/refunds_screen.dart`, titled "Refund History") — **read-only**, no create/edit here (refunds are only initiated from transaction detail). Infinite-scroll list, each row: display id, red amount, customer name (or "Walk-in"), truncated reason, timestamp, processed-by, chevron → bottom-sheet detail (amount hero, details card, "ITEMS REFUNDED" list with unit price × qty).

### 6.11 Bookings / Calendar (inside Checkout)
`checkout/domain/booking_models.dart`: `BookingStatus {scheduled ('SCHEDULED', default), completed, cancelled}`; `Booking {id, customerName, customerPhone, customerEmail?, serviceName, staffId?, staffName?, duration (minutes), date, time ("HH:mm"), notes?, status=scheduled}`, computed `statusLabel`, `timeLabel` (12h format). `BookingRequest` (create/update payload) is the same shape minus id/status.
Repo (`bookings_repository.dart`): `getAll({date?, staffId?, status?, page=1, limit=50})` → `GET /bookings?...` (paginated); `create(req)` → `POST /bookings` with an `Idempotency-Key` header (fresh uuid per call, guards duplicate bookings on retry); `update(id, req)` → `PATCH /bookings/:id`; `updateStatus(id, status)` → `PATCH /bookings/:id/status`; `delete(id)` → `DELETE /bookings/:id`.
Screen (`calendar_tab.dart`, a tab inside Checkout, not its own route): 7-day date strip (today + next 6, "Today" quick-jump), bookings list for the selected day sorted by time — each card: time badge, status badge (blue/green/red), 3-dot menu (Edit / Mark Completed & Cancel [if still scheduled] / Delete), customer name, service, staff (if set), email (if set), notes callout (if present). "Create Booking" → `BookingFormSheet` (shared create/edit): Customer Name*, Phone* (min 7 digits, hidden behind the same `staffCanViewCustomerDetails` gate as Customers), Email (optional), **Service* — free text, not a picker from the real services catalog**, Staff — free text (optional), Duration (min)*, Date/Time pickers (date range today..+90 days), Notes. Offline-aware: save button disables and an offline banner replaces the error slot when `isOfflineProvider` is true. **Structurally decoupled from the Services/Staff catalogs** — no `serviceId` field at all, and completing a booking does not appear to auto-create a checkout transaction; it's a lightweight manual scheduling tool, not an integrated appointment-to-sale pipeline.

### 6.12 Reports (owner-only)
`reports_models.dart`: `SalesSummary {totalRevenue, transactionCount, avgTicket, refundTotal, totalDiscounts, byPaymentMethod (Map, keys CASH/FONEPAY/SPLIT)}`; `StaffPerformance {staffId, staffName, serviceCount, totalRevenue, commission, shiftsCount, totalHours}`; `ServicePopularity {serviceId, serviceName, bookingCount, revenue}`; `InventoryProduct {id, name, stock, lowStockThreshold, status ('ok'|'low'|'critical')}`; `InventoryMovement {item, type ('in'|'out'), qty, note, date}`; `InventoryReport {products, recentMovements}`.
Repo (`reports_repository.dart`): `getSalesSummary({from?, to?})` → `GET /reports/sales`; `getStaffPerformance` → `GET /reports/staff-performance`; `getServicePopularity` → `GET /reports/services`; `getInventoryReport()` → `GET /reports/inventory` (no date params).
Screen (`more/reports_screen.dart`) redirects staff away entirely. Period chips (Today/This Week/This Month/Custom date-range picker) + tab chips (Sales/Staff/Services/Inventory), each tab lazily fetched and cached (changing period clears all caches). **Sales**: black hero card (total revenue + 4 mini-stats), 3 payment-method breakdown cards with horizontal bar charts. **Staff**: sortable table (tap header to sort/reverse) — #, Name, Svcs, Revenue, Commission (column hidden if commission tracking is off). **Services**: sort-by chips (Revenue/Bookings), ranked list with progress bars. **Inventory**: critical-stock warning banner, low-stock card, full product table, recent-movements list.

### 6.13 Settings
Repo (`settings_repository.dart`): `get()` → `GET /settings`; `update(fields)` → `PUT /settings`. **State is defined inline in the screen file itself** (`more/settings_screen.dart`) — no separate provider file. `SalonSettings`: `salonName, address, phone, fonepayId, receiptFooter, autoPrintReceipt, requireCustomer, lowStockAlerts, dailySummary, currency, commissionEnabled, staffCanViewCustomerDetails`. **Important**: `autoPrintReceipt`, `requireCustomer`, `lowStockAlerts`, `dailySummary` are **local-only cosmetic toggles** — never sent to or read from the backend (a code comment explains sending them causes the API to reject the whole request since it rejects unrecognized properties). Only `salonName/address/phone/fonepayId/receiptFooter/currency/commissionEnabled/staffCanViewCustomerDetails` actually persist server-side via `PUT /settings`.
Screen sections, each an inline-edit list (generic single-field edit dialog, not dedicated forms): Business (name, address, phone, currency), Payment (Fonepay Merchant ID), Receipt (auto-print toggle [local], footer text), Staff (commission tracking toggle, staff-can-view-customer-details toggle — this one gates contact-field visibility across Customers/Bookings as documented above), Checkout (required-customer toggle [local]), Notifications (low-stock alerts [local], daily summary [local]), Help (→ Support/FAQ), App (read-only version info), Sign Out (→ confirm → logout).

### 6.14 Notifications
`notification_log_model.dart`: `NotificationLog {id, type (APPOINTMENT_REMINDER_24H/1H, POST_VISIT_THANKYOU, BIRTHDAY_GREETING, RECEIPT, CUSTOM, ...), channel (EMAIL/SMS/PUSH), recipient, subject, body, status, sentAt?, createdAt}`, computed `isSent`, `timeAgo`, `typeLabel`, `channelLabel`.
Repo: `getLogs({page=1, limit=20})` → `GET /notifications/logs` (paginated; the provider only ever fetches limit 50 once, with no infinite-scroll wired despite the repo supporting pagination).
Screen (`notifications/presentation/screens/notifications_screen.dart`, a top-level route reached only via the More-tab badge, not a bottom-tab itself) — **read-only audit log**, no create/delete: type-icon row (color-coded by type), typeLabel + relative time, subject, channel+recipient+sent/failed dot. Unsent rows get a subtle background tint. Error state explicitly notes "Only owners can view notification logs."

### 6.15 Image Library
`image_asset_model.dart`: `ImageAsset {id, name, url, type (ImageAssetType: serviceIcon|staffPhoto|productImage|customerPhoto), isDefault}`.
Repo (`image_library_repository.dart`): `getAll({type?})` → `GET /images?type=`; `upload({file, type, name?, isDefault=false})` → `POST /images/upload` as **multipart** form data; `delete(id)` → `DELETE /images/:id`.
Screen (`more/image_library_screen.dart`): search + type filter chips (All/Services/Staff/Products), 3-col image grid, tap → preview sheet with Delete. "Upload Image" → Camera/Gallery picker → type-picker sheet → name dialog → upload.

### 6.16 More hub
`more_screen.dart` is the umbrella menu — role-conditional (staff and owner see different section lists). Also owns: `setup_guide_screen.dart` (owner onboarding checklist, dynamically checks whether services/items/customers/discounts/cash-drawer/any-sale exist yet), `support_screen.dart` (searchable FAQ + contact links), `privacy_policy_screen.dart`, `terms_screen.dart`, `my_profile_screen.dart` (staff self-service view of their own recent transactions/stats).

---

## 7. API / data layer

- **Client**: one `Dio` instance (`dioProvider`) with `baseUrl` from `EnvConfig`, plus a bare second `refreshDio` (no interceptors) used only for token-refresh calls to avoid interceptor recursion.
- **`ApiClient` wrapper**: `get/post/patch/put/delete`, unwraps the backend's `{success, data, timestamp}` envelope, converts failures into a domain `AppException` (`isUnauthorized`/`isForbidden`/`isNotFound`/`isConflict` helpers).
- **Interceptor stack** (in order): `RetryInterceptor` (exponential backoff, up to 3 retries on connection errors) → `ConnectivityInterceptor` (flips a reachability flag driving a persistent offline banner) → `AuthInterceptor` (injects `Authorization: Bearer <token>` from secure storage) → `RefreshInterceptor` (on 401, exchanges the refresh token once via `/auth/refresh-token`, retries; on genuine rejection, clears session) → `ErrorInterceptor` (maps error bodies/`DioExceptionType`s to friendly messages) → debug-only `LogInterceptor`.
- **DNS fallback** (`core/network/dns_fallback.dart`): a custom `HttpClient.connectionFactory` falling back to DNS-over-HTTPS (Google/Cloudflare resolvers) when the OS resolver fails — resilience for Nepal's variable mobile-network/captive-portal conditions.
- **Repository pattern**: one `XRepository` per feature, one method per REST call. No DTO layer or code-generated models — despite `freezed`/`json_serializable`/`build_runner` all being declared, none are used; every model is hand-written with manual `fromJson`/`copyWith`. Paginated endpoints share a generic `PaginatedResponse<T>` wrapping `PaginationMeta` (total/page/limit/totalPages).

---

## 8. Offline behavior — important caveat

The app declares `drift`, `sqlite3_flutter_libs`, `path_provider` as dependencies (pubspec comment: "offline POS support"), but **none of it is wired up** — no schema files, no generated database classes, no local DB anywhere in `lib/`. What actually exists is pure network-status detection, not offline persistence:

- `connectivity_plus` → device-has-a-network-interface check.
- `ConnectivityInterceptor` → *actual backend reachability* (flips on real connection errors, clears on the next success).
- Combined into `isOfflineProvider`, surfaced as a persistent red `OfflineBanner`.
- `RetryInterceptor` smooths brief blips before surfacing as "offline."
- The Booking form specifically disables its save button and swaps in an offline-specific banner when `isOfflineProvider` is true — the one place in the app with bespoke offline UX beyond the global banner.

**There is no queued/sync-on-reconnect behavior for writes.** If offline, checkout/refunds/edits simply fail with a friendly error — nothing is queued. The backend's `Transaction.offlineId` field has no client-side producer here. Treat "offline-first" as aspirational, not shipped.

---

## 9. Known issues found this session

1. **Dead/duplicate screens** — see §2. ~13 unreferenced files across 9 features; safe cleanup candidates.
2. **`CustomerModel.lastVisitDate` is never actually parsed from the API response** (`fromJson` omits it) — always null, so "Last Visit" always shows "Never" regardless of real history.
3. **4 of 12 `SalonSettings` fields are cosmetic-only** (auto-print, require-customer, low-stock alerts, daily-summary) — they toggle in the UI and persist locally but are never sent to or read from the backend.
4. **Cash Drawer has no visible close-drawer UI action**, despite the repository supporting `close()`.
5. **Bookings are structurally disconnected from the Services/Staff catalogs** — `serviceName`/`staffName` are free text, not references, so a booking's service/staff can't be reliably cross-referenced against real catalog records, and completing a booking doesn't create a transaction.
6. **A genuine concurrency bug in `SecureStorageService`** (found and fixed this session — see §12): `saveTokens`/`saveOwnerTokens`/`saveUser` used `Future.wait([...])` to write two keys in parallel. On the web storage backend, the AES-GCM encryption key is lazily created on first write; two parallel writes can each decide no key exists yet and generate their own, with the second silently orphaning the first (whichever value got encrypted under the losing key becomes permanently undecryptable, throwing `OperationError` on next read). Fixed by making these methods `await` sequentially instead of using `Future.wait`. The same pattern existed a second time in `api_interceptors.dart`'s `RefreshInterceptor` (post-refresh token save) and was fixed identically. Native platforms (Keychain/Keystore) were very likely unaffected by this race — it's specific to the web backend's lazy-key-creation design — but the fix is universally safe regardless of platform.

---

## 10. Build & run

```
flutter pub get
flutter run -d <device>          # android / ios / windows / macos / chrome / edge
flutter build apk --flavor prod  # or --flavor dev / --flavor staging
```
`flutter devices` lists what's available. Web builds additionally require the fixes in §12.

---

## 11. Running on web — two things to know

Web is a genuinely supported target, but two issues surfaced when actually running it (both fixed in this repo as of this session, documented here in case they resurface after a `flutter clean` or on a different machine):

1. **CORS**: the backend's CORS allowlist (`Quick-be/src/main.ts`) defaults to `http://localhost:3001` only (`CORS_ORIGINS` env var, comma-separated). Flutter's web dev server picks a random port unless told otherwise — a random port means every API call gets silently blocked by the browser, which the app's connectivity interceptor then misreports as "No internet connection." Fix: always launch with `flutter run -d chrome --web-port 3001` to match the allowed origin (or add the actual port you want to `CORS_ORIGINS` on the backend).
2. **`assets/icons/` referenced but missing**: `pubspec.yaml` declares `assets/icons/` under `flutter.assets`, but the directory didn't exist on disk (only `assets/images/` did) — this hard-blocks any build (`Error: unable to find directory entry in pubspec.yaml`). Fixed by creating the empty directory. If it's still missing after a fresh checkout, just `mkdir assets/icons`.
3. See §9.6 for the secure-storage race condition, which is real on native platforms too but was actually observed and fixed via web testing.
