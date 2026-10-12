# WATERNow — Complete Business Flow & Technical Architecture

## 1. System Overview & Business Model

WaterNow (Shivnath Agency) operates an enterprise-grade, centralized packaged drinking water manufacturing and multi-tier distribution network in Chhattisgarh, India.

The operational hierarchy comprises:
1. **Central Bottling Plant & Corporate Headquarters**: Responsible for raw material procurement (preforms, caps, labels, shrink film), Bill of Materials (BOM) management, central batch production, finished goods inventory, central pricing, wholesale fulfillment to franchises, and direct company deliveries in uncovered regions.
2. **Authorized Regional Franchises (Dealers)**: Independent distribution centers assigned to specific territorial jurisdictions (Service Districts & Service Zones). Franchises purchase finished stock from the central plant via formal stock requests, maintain local warehouse inventory, and distribute/deliver water products to retail consumers and B2B clients in their assigned territories.
3. **Retail & Commercial Customers**: Individuals and businesses ordering 200ml, 250ml, 500ml, 1 Litre bottles, or 20 Litre water jars. Orders are intelligently routed either to the local serving franchise or directly to central plant dispatch if no active franchise covers the delivery zone.
4. **Sales Executives & Field Staff**: Field staff capturing inbound leads, performing site surveys, conducting client follow-ups, and managing lead journeys.

---

## 2. End-to-End System Architecture

```mermaid
graph TD
    subgraph Clients ["Flutter Multi-Role Applications (Android / iOS / Web)"]
        CA["Customer App<br/>(Browse, Cart, Order, History, Stock Cycle)"]
        FA["Franchise App<br/>(Stock Requests, Inventory, Territory Orders, Collections)"]
        AA["Unified Admin App<br/>(Super Admin & Staff: Plant, BOM, Orders, P&L, Audit)"]
    end

    subgraph API_Gateway ["Django REST Framework API Gateway (Python 3.14 / Django 5.x)"]
        AUTH["JWT & Session Auth<br/>(Role & Scope Enforcement)"]
        ROUTING["Order & Territory Routing Engine<br/>(District / Zone Resolution)"]
        SERVICES["Business Logic Services<br/>(Orders, Inventory, Billing, CRM)"]
    end

    subgraph Storage ["Persistent Data Layer"]
        PG[("PostgreSQL / SQLite Storage Engine<br/>(ACID Transactions, Row Locks)")]
        MEDIA["Media Storage<br/>(Product Assets, FSSAI Docs)"]
    end

    subgraph Messaging ["Push & Event Infrastructure"]
        FCM["Firebase Cloud Messaging (FCM)<br/>(Multicast Push, Android Notification Channels)"]
        LOCAL_NOTIF["Flutter Local Notifications<br/>(Foreground Heads-Up Banners)"]
        IN_APP[("In-App Inboxes<br/>(CustomerNotification, FranchiseNotification, AdminNotification)")]
    end

    CA -->|HTTPS / REST| AUTH
    FA -->|HTTPS / REST| AUTH
    AA -->|HTTPS / REST| AUTH

    AUTH --> ROUTING
    ROUTING --> SERVICES
    SERVICES --> PG
    SERVICES --> MEDIA

    SERVICES -->|Events| IN_APP
    SERVICES -->|FCM Push Payload| FCM
    FCM -->|Push Shade| CA
    FCM -->|Push Shade| FA
    FCM -->|Push Shade| AA
    CA --> LOCAL_NOTIF
    FA --> LOCAL_NOTIF
    AA --> LOCAL_NOTIF
```

---

## 3. Order Lifecycle & Status Progression

The order status machine enforces strict forward progression and immutable audit logging:

```mermaid
stateDiagram-v2
    [*] --> ORDER_PLACED: Customer Places Order
    ORDER_PLACED --> PLANT_APPROVAL: Admin / Plant Approves
    ORDER_PLACED --> CANCELLED: Customer / Admin Cancels (Soft Reservations Released)
    
    PLANT_APPROVAL --> INVOICE_GENERATED: Billing Service Generates Tax Invoice
    PLANT_APPROVAL --> PREPARING: Plant / Franchise Stages Stock
    PLANT_APPROVAL --> CANCELLED: Admin Cancels
    
    INVOICE_GENERATED --> PREPARING: Bottling & Packing
    INVOICE_GENERATED --> CANCELLED: Admin Cancels
    
    PREPARING --> DISPATCH: Physical Handover to Driver
    PREPARING --> CANCELLED: Admin Cancels
    
    DISPATCH --> DELIVERED: Proof of Delivery Confirmed
    DISPATCH --> CANCELLED: Delivery Refusal / Return
    
    DELIVERED --> PAYMENT_COLLECTION: Post-Delivery Reconciliation
    DELIVERED --> [*]: Final Settlement
    CANCELLED --> [*]: Restocked & Audited
```

---

## 4. Central Manufacturing, BOM & Inventory Flow

```mermaid
flowchart TD
    RM[Raw Materials Master Data<br/>Preforms, Caps, Labels, Water, Cartons] -->|PO Inward| RM_STOCK[Raw Material Warehouse Stock]
    RM_STOCK -->|BOM Recipe Consumption| PROD_PLAN[Production Batch Creation]
    PROD_PLAN -->|Qc & Packaging| FG_STOCK[Central Finished Goods Stock<br/>ProductionBatch]
    
    FG_STOCK -->|Direct Company Order| RES_CO[FEFO Reservation - Central]
    FG_STOCK -->|Stock Request Dispatch| TR_OUT[STOCK_TRANSFER_OUT Ledger]
    
    TR_OUT -->|Franchise Receipt| FR_STOCK[Franchise Warehouse Stock<br/>DealerStockBatch]
    FR_STOCK -->|Customer Order| RES_FR[FEFO Reservation - Franchise]
    
    RES_CO -->|Dispatched| SALE_CO[SALE Ledger Entry - Central]
    RES_FR -->|Dispatched| SALE_FR[SALE Ledger Entry - Franchise]
    
    SALE_CO --> REV_CO[Delivered: Revenue & COGS Recognized]
    SALE_FR --> REV_FR[Delivered: Revenue & COGS Recognized]
```

---

## 5. Territory & Dynamic Order Routing

```mermaid
flowchart TD
    Start[Customer Checkout] --> GeoCheck{Delivery Address Territory Known?}
    GeoCheck -->|District / Zone Selected| Lookup[Find Active Franchise Territory Assignment]
    GeoCheck -->|Unregistered Zone| Fallback[Fallback to District Assignment]
    
    Lookup --> Matched{Active Franchise Found?}
    Fallback --> Matched
    
    Matched -->|Yes: Franchise Active| RouteFran[Route to Franchise Fulfillment<br/>order_source = 'FRANCHISE'<br/>serving_franchise = FranchiseProfile]
    Matched -->|No: Unassigned Zone| RouteCo[Route to Direct Company Fulfillment<br/>order_source = 'DIRECT_COMPANY'<br/>serving_franchise = None]
    
    RouteFran --> ResFran[Reserve Stock from DealerStockBatch FEFO]
    RouteCo --> ResCo[Reserve Stock from ProductionBatch FEFO]
    
    ResFran --> NotifyFran[Notify Serving Franchise & Admins via In-App + FCM]
    RouteCo --> NotifyCo[Notify Central Plant Admins Exclusively via In-App + FCM]
```

---

## 6. Real-Time Push Notification & Event Dispatch

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Customer / Client
    actor Admin as Plant Admin / Super Admin
    actor Franchise as Regional Franchise
    participant API as Django REST API (Orders/Inventory)
    participant DB as PostgreSQL Database
    participant FCMService as accounts.fcm_services
    participant Firebase as Google Firebase FCM Server
    participant Device as Mobile OS Notification Shade

    Admin->>API: PATCH /api/orders/{id}/ (status = 'dispatch')
    API->>API: validate_order_status_transition('preparing' -> 'dispatch')
    API->>DB: Atomic Update Order status & save OrderStatusHistory
    API->>DB: Consume FEFO batch reservations & record SALE ledger
    API->>FCMService: notify_order_status_update(order, 'dispatch')
    
    FCMService->>DB: Create CustomerNotification inbox record
    FCMService->>DB: Create FranchiseNotification inbox record
    FCMService->>DB: Create AdminNotification inbox record
    
    FCMService->>DB: Query active DeviceToken for Customer, Franchise & Admins
    FCMService->>Firebase: send_each_for_multicast(MulticastMessage)
    Firebase-->>Device: High-Importance Heads-Up Push Notification
    Device-->>Customer: Display 'Order Dispatched for Delivery! 🚚'
    Device-->>Franchise: Display 'Order #ORD-1234 Dispatched'
    
    Customer->>Device: Tap Push Banner
    Device->>Customer: Flutter Deep Link -> Customer Order Details (#ORD-1234)
```

---

## 7. Comparative Analysis: Intended Architecture vs Actual Implementation

| Architectural Layer | Intended Requirement | Actual Implementation | Verdict |
|:---|:---|:---|:---|
| **Role Authorization** | Customer, Franchise, Admin, Super Admin role separation with scoping | Enforced via `UserProfile.role`, `UserProfile.data_scope`, `IsAdminOrApprovedFranchise` | **PASS** |
| **Catalog Architecture** | 5 Official Initial SKUs with immutable IDs & packaging specs | 5 SKUs strictly enforced: `SHV-200`, `SHV-250`, `SHV-500`, `SHV-1L`, `SHV-20L` | **PASS** |
| **BOM & Manufacturing** | Recipe BOM consumption per batch; central stock separation | `ProductionRecipeBOM` models raw material consumption; `ProductionBatch` separates central stock | **PASS** |
| **Inventory Source of Truth**| Double-entry atomic ledger (`InventoryTransactionLedger`) | Every purchase, batch, transfer, sale, return, adjustment creates atomic ledger entries | **PASS** |
| **Order Routing Engine** | Dynamic territory routing with direct-company fallback | Resolves Chhattisgarh 33 districts & 70 zones; routes to Franchise or Central Plant | **PASS** |
| **Stock Cycle Subscriptions**| Calendar month & day durations with 7-day low-stock alerts | `CustomerStockCycle` implements calendar math, pause/resume, and 7-day alert rules | **PASS** |
| **FCM Push Notifications** | Push delivered to Android notification shade on status updates | Firebase Admin SDK multicast implemented with Android channel & recipient isolation | **PASS (Backend/SDK)** / **BLOCKED (Physical Device)** |
| **Hostinger VPS Target** | Production Nginx + Gunicorn + PostgreSQL deployment | Code is container/VPS ready with systemd & Nginx configs documented; live Render deployed | **READY** |
